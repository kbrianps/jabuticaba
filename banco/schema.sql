create extension if not exists pgcrypto;

create table if not exists saloes (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  nome_assistente text not null default 'Jabu',
  tipo_negocio text not null default 'salão de beleza',
  tom text not null default 'simpático e acolhedor, com no máximo 1 emoji por mensagem',
  fuso text not null default 'America/Sao_Paulo',
  endereco text,
  telefone text,
  funcionamento text,
  politicas text,
  guia_triagem text,
  regras_especificas text,
  evolution_instancia text unique,
  calendar_id text,
  plano text not null default 'teste',
  ativo boolean not null default true,
  criado_em timestamptz not null default now()
);

create table if not exists profissionais (
  id uuid primary key default gen_random_uuid(),
  salao_id uuid not null references saloes(id) on delete cascade,
  nome text not null,
  funcao text,
  dias_trabalho text,
  ativo boolean not null default true,
  unique (salao_id, nome)
);

create table if not exists servicos (
  id uuid primary key default gen_random_uuid(),
  salao_id uuid not null references saloes(id) on delete cascade,
  nome text not null,
  duracao_min integer not null check (duracao_min > 0),
  preco numeric(10,2) not null default 0,
  observacoes text,
  ativo boolean not null default true,
  unique (salao_id, nome)
);

create table if not exists servico_profissionais (
  servico_id uuid not null references servicos(id) on delete cascade,
  profissional_id uuid not null references profissionais(id) on delete cascade,
  primary key (servico_id, profissional_id)
);

create table if not exists clientes (
  id uuid primary key default gen_random_uuid(),
  salao_id uuid not null references saloes(id) on delete cascade,
  telefone text not null,
  nome text,
  email text,
  observacoes text,
  criado_em timestamptz not null default now(),
  ultimo_contato timestamptz not null default now(),
  unique (salao_id, telefone)
);

create table if not exists agendamentos (
  id uuid primary key default gen_random_uuid(),
  salao_id uuid not null references saloes(id) on delete cascade,
  cliente_id uuid references clientes(id) on delete set null,
  servico_id uuid references servicos(id) on delete set null,
  profissional_id uuid references profissionais(id) on delete set null,
  inicio timestamptz not null,
  fim timestamptz not null,
  status text not null default 'marcado' check (status in ('marcado', 'cancelado', 'concluido', 'faltou')),
  google_event_id text,
  observacoes text,
  criado_em timestamptz not null default now()
);

create index if not exists agendamentos_salao_inicio on agendamentos (salao_id, inicio);
create index if not exists agendamentos_cliente on agendamentos (cliente_id);
create index if not exists agendamentos_servico on agendamentos (servico_id);
create index if not exists agendamentos_profissional on agendamentos (profissional_id);
create index if not exists servico_profissionais_profissional on servico_profissionais (profissional_id);

alter table saloes enable row level security;
alter table profissionais enable row level security;
alter table servicos enable row level security;
alter table servico_profissionais enable row level security;
alter table clientes enable row level security;
alter table agendamentos enable row level security;

create or replace function contexto_salao(p_instancia text)
returns jsonb
language sql
stable
as $$
  select jsonb_build_object(
    'salao', to_jsonb(s),
    'profissionais', coalesce((
      select jsonb_agg(jsonb_build_object('nome', p.nome, 'funcao', p.funcao, 'dias_trabalho', p.dias_trabalho) order by p.nome)
      from profissionais p where p.salao_id = s.id and p.ativo
    ), '[]'::jsonb),
    'servicos', coalesce((
      select jsonb_agg(jsonb_build_object(
        'nome', sv.nome,
        'duracao_min', sv.duracao_min,
        'preco', sv.preco,
        'observacoes', sv.observacoes,
        'profissionais', (
          select coalesce(jsonb_agg(p.nome order by p.nome), '[]'::jsonb)
          from servico_profissionais sp join profissionais p on p.id = sp.profissional_id
          where sp.servico_id = sv.id
        )
      ) order by sv.nome)
      from servicos sv where sv.salao_id = s.id and sv.ativo
    ), '[]'::jsonb)
  )
  from saloes s
  where s.evolution_instancia = p_instancia and s.ativo
$$;
