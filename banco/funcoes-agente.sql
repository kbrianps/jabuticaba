alter table saloes add column if not exists whatsapp_responsavel text;
alter table clientes add column if not exists humano_ate timestamptz;
alter table agendamentos add column if not exists lembrete_enviado_em timestamptz;

-- Quantas horas antes do horário o cliente ainda pode cancelar ou remarcar pelo WhatsApp (0 = sem limite).
alter table saloes add column if not exists antecedencia_minima_horas integer not null default 0
  check (antecedencia_minima_horas >= 0);

-- Impede dois agendamentos marcados no mesmo horário com o mesmo profissional.
create extension if not exists btree_gist with schema extensions;

do $$
begin
  if not exists (select 1 from pg_constraint where conname = 'agendamentos_sem_choque') then
    alter table agendamentos add constraint agendamentos_sem_choque
      exclude using gist (profissional_id with =, tstzrange(inicio, fim) with &&)
      where (status = 'marcado' and profissional_id is not null);
  end if;
end
$$;

create or replace function horario_livre(
  p_salao_id uuid,
  p_profissional text,
  p_inicio timestamptz,
  p_fim timestamptz,
  p_agendamento_id uuid default null
)
returns jsonb
language sql
stable
as $$
  with prof as (
    select id from profissionais
    where salao_id = p_salao_id and (lower(nome) = lower(trim(p_profissional)) or nome ilike trim(p_profissional) || '%')
    order by lower(nome) = lower(trim(p_profissional)) desc limit 1
  )
  select case
    when not exists (select 1 from prof) then jsonb_build_object('livre', false, 'erro', 'Profissional não encontrado')
    when p_fim <= p_inicio then jsonb_build_object('livre', false, 'erro', 'O fim precisa ser depois do início')
    when p_inicio <= now() then jsonb_build_object('livre', false, 'erro', 'Esse horário já passou')
    else jsonb_build_object('livre', not exists (
      select 1 from agendamentos a
      where a.profissional_id = (select id from prof)
        and a.status = 'marcado'
        and a.id is distinct from p_agendamento_id
        and tstzrange(a.inicio, a.fim) && tstzrange(p_inicio, p_fim)
    ))
  end;
$$;

create or replace function iniciar_conversa(p_instancia text, p_telefone text)
returns jsonb
language plpgsql
as $$
declare
  v_salao saloes;
  v_cliente clientes;
begin
  select * into v_salao from saloes where evolution_instancia = p_instancia and ativo;
  if not found then
    return null;
  end if;

  insert into clientes (salao_id, telefone)
  values (v_salao.id, p_telefone)
  on conflict (salao_id, telefone) do update set ultimo_contato = now()
  returning * into v_cliente;

  return contexto_salao(p_instancia) || jsonb_build_object(
    'cliente', jsonb_build_object('nome', v_cliente.nome, 'email', v_cliente.email, 'humano_ate', v_cliente.humano_ate),
    'agendamentos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'id', a.id,
        'servico', sv.nome,
        'profissional', p.nome,
        'quando', to_char(a.inicio at time zone v_salao.fuso, 'DD/MM/YYYY HH24:MI'),
        'duracao_min', (extract(epoch from a.fim - a.inicio) / 60)::int,
        'pode_alterar', a.inicio >= now() + make_interval(hours => v_salao.antecedencia_minima_horas)
      ) order by a.inicio)
      from agendamentos a
      left join servicos sv on sv.id = a.servico_id
      left join profissionais p on p.id = a.profissional_id
      where a.cliente_id = v_cliente.id and a.status = 'marcado' and a.inicio > now()
    ), '[]'::jsonb)
  );
end
$$;

create or replace function salvar_cliente(p_salao_id uuid, p_telefone text, p_nome text default null, p_email text default null)
returns jsonb
language sql
as $$
  update clientes set
    nome = coalesce(nullif(trim(p_nome), ''), nome),
    email = coalesce(nullif(lower(trim(p_email)), ''), email)
  where salao_id = p_salao_id and telefone = p_telefone
  returning jsonb_build_object('nome', nome, 'email', email);
$$;

create or replace function registrar_agendamento(
  p_salao_id uuid,
  p_telefone text,
  p_servico text,
  p_profissional text,
  p_inicio timestamptz,
  p_fim timestamptz,
  p_google_event_id text,
  p_observacoes text default null
)
returns jsonb
language plpgsql
as $$
declare
  v_resultado jsonb;
begin
  if p_fim <= p_inicio then
    return jsonb_build_object('erro', 'O fim precisa ser depois do início', 'motivo', 'horario_invalido');
  end if;

  insert into agendamentos (salao_id, cliente_id, servico_id, profissional_id, inicio, fim, google_event_id, observacoes)
  select
    p_salao_id,
    (select id from clientes where salao_id = p_salao_id and telefone = p_telefone),
    (select id from servicos
      where salao_id = p_salao_id and (lower(nome) = lower(trim(p_servico)) or nome ilike trim(p_servico) || '%')
      order by lower(nome) = lower(trim(p_servico)) desc limit 1),
    (select id from profissionais
      where salao_id = p_salao_id and (lower(nome) = lower(trim(p_profissional)) or nome ilike trim(p_profissional) || '%')
      order by lower(nome) = lower(trim(p_profissional)) desc limit 1),
    p_inicio,
    p_fim,
    nullif(trim(p_google_event_id), ''),
    p_observacoes
  returning jsonb_build_object('id', id, 'status', status) into v_resultado;

  return v_resultado;
exception
  when exclusion_violation then
    return jsonb_build_object('erro', 'O profissional já tem outro atendimento nesse horário', 'motivo', 'horario_ocupado');
end
$$;

-- Acha um agendamento marcado do próprio cliente e confere se ainda está no prazo para mudar.
create or replace function agendamento_alteravel(p_salao_id uuid, p_telefone text, p_agendamento_id uuid)
returns jsonb
language plpgsql
as $$
declare
  v_inicio timestamptz;
  v_horas integer;
begin
  select a.inicio, s.antecedencia_minima_horas into v_inicio, v_horas
  from agendamentos a
  join clientes c on c.id = a.cliente_id
  join saloes s on s.id = a.salao_id
  where a.id = p_agendamento_id
    and a.salao_id = p_salao_id
    and c.telefone = p_telefone
    and a.status = 'marcado'
  for update of a;

  if not found then
    return jsonb_build_object('erro', 'Agendamento não encontrado para este cliente', 'motivo', 'nao_encontrado');
  end if;

  if v_inicio < now() + make_interval(hours => v_horas) then
    return jsonb_build_object(
      'erro', 'Fora do prazo para mudar pelo WhatsApp',
      'motivo', 'fora_do_prazo',
      'antecedencia_minima_horas', v_horas
    );
  end if;

  return null;
end
$$;

create or replace function cancelar_agendamento(p_salao_id uuid, p_telefone text, p_agendamento_id uuid)
returns jsonb
language plpgsql
as $$
declare
  v_erro jsonb;
  v_resultado jsonb;
begin
  v_erro := agendamento_alteravel(p_salao_id, p_telefone, p_agendamento_id);
  if v_erro is not null then
    return v_erro;
  end if;

  update agendamentos set status = 'cancelado'
  where id = p_agendamento_id
  returning jsonb_build_object('id', id, 'status', status, 'google_event_id', google_event_id) into v_resultado;

  return v_resultado;
end
$$;

create or replace function remarcar_agendamento(p_salao_id uuid, p_telefone text, p_agendamento_id uuid, p_inicio timestamptz, p_fim timestamptz)
returns jsonb
language plpgsql
as $$
declare
  v_erro jsonb;
  v_resultado jsonb;
begin
  if p_fim <= p_inicio then
    return jsonb_build_object('erro', 'O fim precisa ser depois do início', 'motivo', 'horario_invalido');
  end if;
  if p_inicio <= now() then
    return jsonb_build_object('erro', 'Esse horário já passou', 'motivo', 'horario_invalido');
  end if;

  v_erro := agendamento_alteravel(p_salao_id, p_telefone, p_agendamento_id);
  if v_erro is not null then
    return v_erro;
  end if;

  update agendamentos set inicio = p_inicio, fim = p_fim, lembrete_enviado_em = null
  where id = p_agendamento_id
  returning jsonb_build_object('id', id, 'status', status, 'google_event_id', google_event_id) into v_resultado;

  return v_resultado;
exception
  when exclusion_violation then
    return jsonb_build_object('erro', 'O profissional já tem outro atendimento nesse horário', 'motivo', 'horario_ocupado');
end
$$;

create or replace function pausar_atendimento(p_salao_id uuid, p_telefone text)
returns jsonb
language sql
as $$
  update clientes set humano_ate = now() + interval '12 hours'
  where salao_id = p_salao_id and telefone = p_telefone
  returning jsonb_build_object('humano_ate', humano_ate);
$$;

create or replace function lembretes_pendentes()
returns setof jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'id', a.id,
    'instancia', s.evolution_instancia,
    'nome_negocio', s.nome,
    'nome_assistente', s.nome_assistente,
    'telefone', c.telefone,
    'cliente', c.nome,
    'servico', sv.nome,
    'profissional', p.nome,
    'data', to_char(a.inicio at time zone s.fuso, 'DD/MM'),
    'hora', to_char(a.inicio at time zone s.fuso, 'HH24:MI')
  )
  from agendamentos a
  join saloes s on s.id = a.salao_id
  join clientes c on c.id = a.cliente_id
  left join servicos sv on sv.id = a.servico_id
  left join profissionais p on p.id = a.profissional_id
  where a.status = 'marcado'
    and a.lembrete_enviado_em is null
    and s.ativo
    and (a.inicio at time zone s.fuso)::date = (now() at time zone s.fuso)::date + 1
  order by a.inicio
$$;

create or replace function marcar_lembrete(p_agendamento_id uuid)
returns jsonb
language sql
as $$
  update agendamentos set lembrete_enviado_em = now()
  where id = p_agendamento_id
  returning jsonb_build_object('id', id, 'lembrete_enviado_em', lembrete_enviado_em);
$$;

revoke execute on function
  contexto_salao(text),
  iniciar_conversa(text, text),
  salvar_cliente(uuid, text, text, text),
  registrar_agendamento(uuid, text, text, text, timestamptz, timestamptz, text, text),
  cancelar_agendamento(uuid, text, uuid),
  remarcar_agendamento(uuid, text, uuid, timestamptz, timestamptz),
  pausar_atendimento(uuid, text),
  lembretes_pendentes(),
  marcar_lembrete(uuid),
  horario_livre(uuid, text, timestamptz, timestamptz, uuid),
  agendamento_alteravel(uuid, text, uuid)
from public, anon, authenticated;

grant execute on function
  contexto_salao(text),
  iniciar_conversa(text, text),
  salvar_cliente(uuid, text, text, text),
  registrar_agendamento(uuid, text, text, text, timestamptz, timestamptz, text, text),
  cancelar_agendamento(uuid, text, uuid),
  remarcar_agendamento(uuid, text, uuid, timestamptz, timestamptz),
  pausar_atendimento(uuid, text),
  lembretes_pendentes(),
  marcar_lembrete(uuid),
  horario_livre(uuid, text, timestamptz, timestamptz, uuid),
  agendamento_alteravel(uuid, text, uuid)
to service_role;

-- Fixa o search_path para ninguém trocar as tabelas usadas pelas funções.
alter function contexto_salao(text) set search_path = public;
alter function iniciar_conversa(text, text) set search_path = public;
alter function salvar_cliente(uuid, text, text, text) set search_path = public;
alter function registrar_agendamento(uuid, text, text, text, timestamptz, timestamptz, text, text) set search_path = public;
alter function cancelar_agendamento(uuid, text, uuid) set search_path = public;
alter function remarcar_agendamento(uuid, text, uuid, timestamptz, timestamptz) set search_path = public;
alter function pausar_atendimento(uuid, text) set search_path = public;
alter function lembretes_pendentes() set search_path = public;
alter function marcar_lembrete(uuid) set search_path = public;
alter function horario_livre(uuid, text, timestamptz, timestamptz, uuid) set search_path = public;
alter function agendamento_alteravel(uuid, text, uuid) set search_path = public;

notify pgrst, 'reload schema';
