# Agente Autônomo de Atendimento e Agendamento para Salão de Beleza

**Disciplina:** ACSO – Sistemas Autônomos
**Professor:** Gilberto Gomes
**Instituição:** Centro Universitário São José / FAETEC – Tecnólogo em Sistemas de Informação
**Alunos:** _preencher_
**Data:** 24/10/2026

> Rascunho base. Partes marcadas com _preencher_ dependem dos testes do grupo.

## 1. Escopo do problema

Salões de beleza recebem a maior parte dos pedidos de horário pelo WhatsApp. Quem responde geralmente é a própria cabeleireira, entre um atendimento e outro, ou a recepção, que também atende quem está no salão. Com isso, mensagens ficam horas sem resposta, clientes desistem e marcam em outro lugar, e acontecem erros como encaixar um serviço de 3 horas em um intervalo de 1 hora.

**Escopo restrito deste trabalho:** um salão fictício (Salão Jabuticaba) com três profissionais e onze serviços. O agente atende por chat, entende o que a cliente quer (mesmo quando ela não sabe o nome do serviço), indica o serviço, a profissional, a duração e o preço, oferece horários livres da semana e, quando a cliente confirma, cria o atendimento no Google Agenda e envia o convite por e-mail.

**Fora do escopo:** pagamento, cancelamento e remarcação, programa de fidelidade e envio de fotos.

**Aplicação customizável:** o agente foi construído como um MVP genérico. O fluxo e o prompt não citam o salão; tudo o que é do negócio (nome, serviços, preços, profissionais e regras) fica em um único nó de configuração. Assim, a mesma solução pode ser adaptada a uma barbearia ou a um estúdio de unhas só trocando a configuração.

## 2. Objetivos

**Objetivo geral:** desenvolver um agente autônomo de IA que realize o atendimento inicial e o agendamento de serviços de um salão de beleza sem intervenção humana.

**Objetivos específicos:**
1. Identificar o serviço adequado a partir da descrição da cliente.
2. Escolher a profissional certa e respeitar a duração de cada serviço.
3. Consultar a agenda real e oferecer apenas horários livres.
4. Criar o evento na agenda e enviar o convite por e-mail após a confirmação.
5. Responder dúvidas sobre o salão usando uma base de conhecimento, sem inventar preços.
6. Aplicar a regra de segurança do teste de alergia para serviços com química.
7. Medir a taxa de acerto, o tempo de resposta e os cuidados com os dados.

## 3. Pilha tecnológica e justificativa

| Componente | Ferramenta | Por que foi escolhida |
|---|---|---|
| Orquestração | n8n Cloud | Tem nó pronto de AI Agent com memória e ferramentas, não exige instalação e o fluxo pode ser levado para um n8n próprio depois |
| Modelo de linguagem | DeepSeek Chat | Custo muito baixo por mensagem e bom desempenho em português |
| Agenda | Google Calendar API | Gratuita, popular e envia convites por e-mail automaticamente |
| Configuração do negócio | Nó Config (Edit Fields) do n8n | Um único lugar para trocar os dados do negócio |
| Interface | Chat do n8n (simulando WhatsApp) / Evolution API | Teste imediato; WhatsApp real como evolução |

## 4. Tipo de abordagem: visual (low-code)

O professor apresentou dois caminhos: abordagem visual (no-code / low-code) e abordagem com código (Python com CrewAI ou LangChain). Escolhemos a **abordagem visual com low-code**.

**No-code vs. low-code**

| | No-code | Low-code |
|---|---|---|
| O que é | Monta tudo só arrastando blocos, sem escrever código | Monta arrastando blocos, mas permite escrever pequenos trechos de código quando precisa |
| Exemplos | OpenAI Agent Builder, Copilot Studio | n8n, Flowise |
| Vantagens | Muito rápido, qualquer pessoa usa | Rápido e ainda flexível, integra com qualquer API |
| Desvantagens | Preso aos recursos da plataforma, geralmente pago, dados ficam na big tech | Exige noções de API, JSON e expressões |

**Justificativa:** o n8n é low-code. Ele permite montar o agente visualmente, o que cabe no prazo do trabalho, mas também aceita expressões e chamadas HTTP, o que foi necessário para passar a data atual ao agente e para integrar o WhatsApp. Por ser open-source, o mesmo fluxo pode sair do n8n Cloud, usado no MVP pela praticidade, e rodar em um servidor próprio, sem mensalidade e com os dados das clientes sob controle do negócio.

Comparado à abordagem em Python (CrewAI / LangChain), o n8n entrega o mesmo conceito de agente (LLM + memória + ferramentas) com menos tempo de desenvolvimento. A desvantagem é ter menos controle fino do que um código escrito do zero.

## 5. Diagrama de operações

```
Interface (Chat)  →  Cérebro (LLM)  →  Tomada de Decisão  →  Execução da Ferramenta
   Cliente           DeepSeek no        É dúvida? Qual          Google Agenda (ver)
   escreve no        AI Agent do        serviço? Precisa        Google Agenda (criar)
   chat              n8n + memória      de teste? Quer          Resposta à cliente
                     + Config           horário? Confirmou?
```

_Inserir aqui o print do fluxo no n8n e o diagrama de blocos desenhado (ex.: draw.io)._

**Descrição das operações**
1. **Interface:** a cliente envia a mensagem pelo chat. O n8n recebe pelo gatilho "When chat message received".
2. **Configuração:** o nó Config acrescenta os dados do negócio (nome, serviços, regras).
3. **Cérebro:** o nó AI Agent monta o prompt com esses dados e envia a mensagem e o histórico (Simple Memory) para o DeepSeek.
4. **Tomada de decisão:** o modelo decide se responde direto, se consulta a agenda ou se cria o evento.
5. **Execução da ferramenta:** o n8n executa a ferramenta escolhida e devolve o resultado ao modelo, que escreve a resposta final.

## 6. Etapas do projeto

### 6.1 Definição do problema
Ver seção 1.

### 6.2 Configuração do prompt base
O prompt completo está em `prompts/prompt-base.md`. Ele define:
- **Papel:** "Você é a Jabu, assistente virtual de atendimento do Salão Jabuticaba".
- **Limites:** não inventa serviço, preço ou horário, não promete resultado e não fala de assuntos fora do salão.
- **Regras de saída:** mensagens curtas como no WhatsApp, formato padrão de data e hora, título padrão do evento.
- **Segurança:** exige teste de alergia antes da primeira química e não agenda química para quem já teve reação.

### 6.3 Conexão da base de dados (RAG)
As informações do salão (serviços, duração, preços, profissionais, regras) ficam no campo `base_conhecimento` do nó Config (`negocios/salao.md`) e são entregues ao modelo junto com o prompt a cada mensagem. Isso evita alucinações, porque o preço e a duração vêm de um texto confiável e não da "memória" do modelo. Se o salão mudar um preço, basta editar o Config.

Como a base de um pequeno negócio é curta, ela cabe inteira no prompt, que é a forma mais simples de alimentar o agente com dados. Em um RAG completo (Retrieval-Augmented Generation), o agente buscaria apenas os trechos relevantes em uma base maior, como manuais ou um banco vetorial. Esse é o próximo passo caso a base cresça.

### 6.4 Criação das ferramentas / APIs
| Ferramenta | Nó do n8n | O que faz |
|---|---|---|
| ver_agenda | Google Calendar Tool (Get Many) | Lista os atendimentos já marcados em um período |
| criar_agendamento | Google Calendar Tool (Create) | Cria o evento com a cliente como convidada |

**Integrações configuradas:** chave de API do DeepSeek e credencial OAuth2 do Google no gerenciador de credenciais do n8n (as chaves não ficam no fluxo nem no GitHub). No bônus com WhatsApp: webhook da Evolution API apontando para o n8n.

### 6.5 Testes e refinamento
Ver seção 7. _Descrever aqui o que foi ajustado no prompt depois dos testes, ex.: "o agente marcava mechas às 17h de sábado, que não cabem antes de fechar, então adicionamos a regra..."._

## 7. Camada de avaliação

**Taxa de acerto:** cada caso foi testado e marcado como certo ou errado.

| # | Mensagem da cliente | Esperado | Resultado | Tempo (s) |
|---|---|---|---|---|
| 1 | "Quero cobrir meus fios brancos" | Coloração com Juliana, 2h, R$ 180 | _preencher_ | |
| 2 | "Meu cabelo está muito ressecado" | Hidratação com Juliana | | |
| 3 | "Quero fazer as unhas da mão e do pé" | Mão e pé com Patrícia, 1h30 | | |
| 4 | "Quanto custa o corte masculino?" | R$ 45,00 (da base) | | |
| 5 | "Vocês abrem segunda?" | Diz que fecha segunda | | |
| 6 | Primeira vez fazendo mechas | Oferece teste de alergia 48h antes | | |
| 7 | "Da última vez a tinta me deu ferida na cabeça" | Não agenda química, orienta dermatologista | | |
| 8 | "Me ajuda com meu dever de matemática" | Recusa, fora do escopo | | |
| 9 | Pede mechas sábado às 15h | Diz que não cabe (fecha 17h), oferece outro | | |
| 10 | Confirma o agendamento | Evento criado com duração certa e convite no e-mail | | |

**Taxa de acerto:** _x de 10 (y%)_.

**Tempo de execução:** medido no histórico de execuções do n8n (aba "Executions"). Média: _preencher_ segundos por resposta.

**Segurança dos dados:**
- Chaves de API guardadas no gerenciador de credenciais do n8n, fora do código.
- Ferramentas com poder limitado: o agente só consegue ler e criar eventos na agenda do negócio, não consegue apagar nem acessar outros dados.
- O agente só pede nome e e-mail, o mínimo para agendar (princípio da LGPD).
- Testes feitos apenas com dados fictícios.

## 8. Conclusão

_preencher: o que funcionou, o que o grupo aprendeu e próximos passos (WhatsApp real, lembrete no dia anterior, cancelamento, oferecer para salões de verdade)._

## Bibliografia

- Microsoft. Como construir um agente de IA: um guia simples. Disponível em: https://news.microsoft.com/source/latam/ia-pt-br/como-construir-um-agente-de-ia-um-guia-simples/?lang=pt-br
- n8n. Documentação do AI Agent. Disponível em: https://docs.n8n.io
- DeepSeek. API Docs. Disponível em: https://api-docs.deepseek.com
