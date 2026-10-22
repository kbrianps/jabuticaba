# Configuração: Salão Jabuticaba

Salão de beleza fictício, o primeiro caso do MVP. Estes são os valores que estão no nó **Config** do fluxo [n8n/agente-agendamento.json](../n8n/agente-agendamento.json).

Para adaptar a outro negócio, copie [modelo.md](modelo.md), preencha e cole os valores no nó Config.

## Campos curtos

| Campo | Valor |
|---|---|
| nome_negocio | Salão Jabuticaba |
| nome_assistente | Jabu |
| tipo_negocio | salão de beleza |
| tom | simpático e acolhedor, com no máximo 1 emoji por mensagem |
| fuso | America/Sao_Paulo |

## base_conhecimento

```
SOBRE
Endereço: Rua das Jabuticabeiras, 100, loja 3, Centro, Rio de Janeiro, RJ
Telefone: (21) 0000-0000
Funcionamento: terça a sexta das 9h às 19h, sábado das 8h às 17h. Fechado domingo, segunda e feriados.
Almoço: não há atendimentos entre 12h e 13h.

PROFISSIONAIS
- Juliana: cabeleireira (corte feminino, escova, hidratação, coloração, mechas). Terça a sábado.
- Rafael: barbeiro e cabeleireiro (corte masculino, corte feminino, barba). Quarta a sábado.
- Patrícia: manicure, pedicure e sobrancelha. Terça a sábado.

SERVIÇOS (duração, preço, profissional)
- Corte feminino: 1h, R$ 80, Juliana ou Rafael
- Corte masculino: 30 min, R$ 45, Rafael
- Barba: 30 min, R$ 35, Rafael
- Escova: 45 min, R$ 60, Juliana
- Hidratação: 45 min, R$ 70, Juliana
- Coloração (raiz ou cabelo todo): 2h, R$ 180, Juliana
- Mechas / luzes: 3h, R$ 300, Juliana
- Manicure: 45 min, R$ 35, Patrícia
- Pedicure: 45 min, R$ 40, Patrícia
- Mão e pé: 1h30, R$ 65, Patrícia
- Design de sobrancelha: 30 min, R$ 40, Patrícia
- Teste de alergia (química): 15 min, grátis, Juliana

GUIA PARA A TRIAGEM
- "Cobrir fios brancos", "mudar a cor", "retocar a raiz": Coloração
- "Clarear", "luzes", "ficar loira": Mechas / luzes
- "Cabelo ressecado", "sem brilho", "quebradiço": Hidratação
- "Arrumar o cabelo para uma festa", "deixar liso hoje": Escova
- "Aparar as pontas", "mudar o corte": Corte
- "Fazer as unhas": Manicure, Pedicure ou Mão e pé

POLÍTICAS
- Chegar 10 minutos antes. Atraso de mais de 15 minutos pode precisar ser remarcado.
- Cancelamento ou remarcação: avisar com 24 horas de antecedência.
- Pagamento: Pix, débito, crédito (até 3x sem juros acima de R$ 150) e dinheiro.
```

## regras_especificas

```
- Coloração e mechas: pergunte se a cliente já fez química no salão. Se nunca fez, avise que precisa do teste de alergia gratuito pelo menos 48 horas antes e ofereça marcar o teste primeiro.
- Se a cliente contar que já teve alergia, coceira forte ou ferida no couro cabeludo depois de química, não agende coloração nem mechas. Oriente procurar um dermatologista e ofereça um serviço sem química.
```
