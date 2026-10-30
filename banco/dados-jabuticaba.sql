insert into saloes (nome, nome_assistente, tipo_negocio, endereco, telefone, funcionamento, politicas, guia_triagem, regras_especificas, evolution_instancia, calendar_id)
values (
  'Salão Jabuticaba',
  'Jabu',
  'salão de beleza',
  'Rua das Jabuticabeiras, 100, loja 3, Centro, Rio de Janeiro, RJ',
  '(21) 0000-0000',
  'Terça a sexta das 9h às 19h, sábado das 8h às 17h. Fechado domingo, segunda e feriados. Não há atendimentos entre 12h e 13h (almoço).',
  E'- Chegar 10 minutos antes. Atraso de mais de 15 minutos pode precisar ser remarcado.\n- Cancelamento ou remarcação: avisar com 24 horas de antecedência.\n- Pagamento: Pix, débito, crédito (até 3x sem juros acima de R$ 150) e dinheiro.',
  E'- "Cobrir fios brancos", "mudar a cor", "retocar a raiz": Coloração\n- "Clarear", "luzes", "ficar loira": Mechas / luzes\n- "Cabelo ressecado", "sem brilho", "quebradiço": Hidratação\n- "Arrumar o cabelo para uma festa", "deixar liso hoje": Escova\n- "Aparar as pontas", "mudar o corte": Corte\n- "Fazer as unhas": Manicure, Pedicure ou Mão e pé',
  E'- Coloração e mechas: pergunte se a cliente já fez química no salão. Se nunca fez, avise que precisa do teste de alergia gratuito pelo menos 48 horas antes e ofereça marcar o teste primeiro.\n- Se a cliente contar que já teve alergia, coceira forte ou ferida no couro cabeludo depois de química, não agende coloração nem mechas. Oriente procurar um dermatologista e ofereça um serviço sem química.',
  'jabuticaba',
  'aarthurps@gmail.com'
)
on conflict (evolution_instancia) do nothing;

with s as (select id from saloes where evolution_instancia = 'jabuticaba')
insert into profissionais (salao_id, nome, funcao, dias_trabalho)
select s.id, v.nome, v.funcao, v.dias from s, (values
  ('Juliana', 'cabeleireira', 'terça a sábado'),
  ('Rafael', 'barbeiro e cabeleireiro', 'quarta a sábado'),
  ('Patrícia', 'manicure, pedicure e sobrancelha', 'terça a sábado')
) as v(nome, funcao, dias)
on conflict (salao_id, nome) do nothing;

with s as (select id from saloes where evolution_instancia = 'jabuticaba')
insert into servicos (salao_id, nome, duracao_min, preco)
select s.id, v.nome, v.duracao, v.preco from s, (values
  ('Corte feminino', 60, 80),
  ('Corte masculino', 30, 45),
  ('Barba', 30, 35),
  ('Escova', 45, 60),
  ('Hidratação', 45, 70),
  ('Coloração (raiz ou cabelo todo)', 120, 180),
  ('Mechas / luzes', 180, 300),
  ('Manicure', 45, 35),
  ('Pedicure', 45, 40),
  ('Mão e pé', 90, 65),
  ('Design de sobrancelha', 30, 40),
  ('Teste de alergia (química)', 15, 0)
) as v(nome, duracao, preco)
on conflict (salao_id, nome) do nothing;

insert into servico_profissionais (servico_id, profissional_id)
select sv.id, p.id
from saloes s
join servicos sv on sv.salao_id = s.id
join profissionais p on p.salao_id = s.id
join (values
  ('Corte feminino', 'Juliana'),
  ('Corte feminino', 'Rafael'),
  ('Corte masculino', 'Rafael'),
  ('Barba', 'Rafael'),
  ('Escova', 'Juliana'),
  ('Hidratação', 'Juliana'),
  ('Coloração (raiz ou cabelo todo)', 'Juliana'),
  ('Mechas / luzes', 'Juliana'),
  ('Manicure', 'Patrícia'),
  ('Pedicure', 'Patrícia'),
  ('Mão e pé', 'Patrícia'),
  ('Design de sobrancelha', 'Patrícia'),
  ('Teste de alergia (química)', 'Juliana')
) as m(servico, profissional) on m.servico = sv.nome and m.profissional = p.nome
where s.evolution_instancia = 'jabuticaba'
on conflict do nothing;

select contexto_salao('jabuticaba');
