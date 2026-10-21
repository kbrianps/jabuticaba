# Agente Autônomo de Triagem e Pré-Agendamento de Consultas

**Disciplina:** ACSO – Sistemas Autônomos
**Professor:** Gilberto Gomes
**Instituição:** Centro Universitário São José / FAETEC – Tecnólogo em Sistemas de Informação
**Alunos:** _preencher_
**Data:** 24/10/2026

> Rascunho base. Partes marcadas com _preencher_ dependem dos testes do grupo.

## 1. Escopo do problema

Clínicas pequenas perdem pacientes porque demoram a responder no WhatsApp sobre horários disponíveis. A recepção atende telefone, paciente presencial e mensagens ao mesmo tempo, e quem pergunta fora do horário comercial só recebe resposta no dia seguinte, quando muitas vezes já marcou em outro lugar.

**Escopo restrito deste trabalho:** uma clínica fictícia (Clínica Jabuticaba) com três especialidades: Clínico Geral, Cardiologia e Dermatologia. O agente atende por chat, faz a triagem do motivo da consulta, oferece horários livres da semana e, quando o paciente confirma, cria a consulta no Google Agenda e envia o convite por e-mail para o paciente e para a clínica.

**Fora do escopo:** diagnóstico médico, prescrição, pagamento, prontuário e cancelamento de consultas.

## 2. Objetivos

**Objetivo geral:** desenvolver um agente autônomo de IA que realize a triagem inicial e o pré-agendamento de consultas sem intervenção humana.

**Objetivos específicos:**
1. Identificar a especialidade adequada a partir do relato do paciente.
2. Consultar a agenda real e oferecer apenas horários livres.
3. Criar o evento na agenda e enviar o convite por e-mail após a confirmação.
4. Responder dúvidas sobre a clínica usando uma base de conhecimento, sem inventar informações.
5. Reconhecer situações de urgência e orientar o paciente a buscar o pronto-socorro.
6. Medir a taxa de acerto, o tempo de resposta e os cuidados com os dados.

## 3. Pilha tecnológica e justificativa

| Componente | Ferramenta | Por que foi escolhida |
|---|---|---|
| Orquestração | n8n (self-hosted) | Open-source, gratuito, tem nó pronto de AI Agent com memória e ferramentas |
| Modelo de linguagem | DeepSeek Chat | Custo muito baixo por mensagem e bom desempenho em português |
| Agenda | Google Calendar API | Gratuita, popular e envia convites por e-mail automaticamente |
| Base de conhecimento | Google Docs | Fácil de a clínica editar sem saber programar |
| Interface | Chat do n8n (simulando WhatsApp) / Evolution API | Teste imediato; WhatsApp real como evolução |
| Infraestrutura | Docker | Sobe o sistema com um comando em qualquer computador |

## 4. Tipo de abordagem: visual (low-code)

O professor apresentou dois caminhos: abordagem visual (no-code / low-code) e abordagem com código (Python com CrewAI ou LangChain). Escolhemos a **abordagem visual com low-code**.

**No-code vs. low-code**

| | No-code | Low-code |
|---|---|---|
| O que é | Monta tudo só arrastando blocos, sem escrever código | Monta arrastando blocos, mas permite escrever pequenos trechos de código quando precisa |
| Exemplos | OpenAI Agent Builder, Copilot Studio | n8n, Flowise |
| Vantagens | Muito rápido, qualquer pessoa usa | Rápido e ainda flexível, integra com qualquer API |
| Desvantagens | Preso aos recursos da plataforma, geralmente pago, dados ficam na big tech | Exige noções de API, JSON e expressões |

**Justificativa:** o n8n é low-code. Ele permite montar o agente visualmente, o que cabe no prazo do trabalho, mas também aceita expressões e chamadas HTTP, o que foi necessário para passar a data atual ao agente e para integrar o WhatsApp. Por ser open-source e rodar no nosso próprio computador, os dados dos pacientes não ficam em uma plataforma de terceiros e não há mensalidade.

Comparado à abordagem em Python (CrewAI / LangChain), o n8n entrega o mesmo conceito de agente (LLM + memória + ferramentas) com menos tempo de desenvolvimento. A desvantagem é ter menos controle fino do que um código escrito do zero.

## 5. Diagrama de operações

```
Interface (Chat)  →  Cérebro (LLM)  →  Tomada de Decisão  →  Execução da Ferramenta
   Paciente          DeepSeek no        É dúvida? É            Google Docs (base)
   escreve no        AI Agent do        triagem? Quer           Google Agenda (ver)
   chat              n8n + memória      horário? Confirmou?     Google Agenda (criar)
                                        É urgência?             Resposta ao paciente
```

_Inserir aqui o print do fluxo no n8n e o diagrama de blocos desenhado (ex.: draw.io)._

**Descrição das operações**
1. **Interface:** o paciente envia a mensagem pelo chat. O n8n recebe pelo gatilho "When chat message received".
2. **Cérebro:** o nó AI Agent envia a mensagem, o histórico (Simple Memory) e o prompt base para o DeepSeek.
3. **Tomada de decisão:** o modelo decide se responde direto, se consulta a base de conhecimento, se consulta a agenda ou se cria o evento.
4. **Execução da ferramenta:** o n8n executa a ferramenta escolhida e devolve o resultado ao modelo, que escreve a resposta final.

## 6. Etapas do projeto

### 6.1 Definição do problema
Ver seção 1.

### 6.2 Configuração do prompt base
O prompt completo está em `prompts/prompt-base.md`. Ele define:
- **Papel:** "Você é a Jabu, assistente virtual de atendimento da Clínica Jabuticaba".
- **Limites:** não dá diagnóstico, não indica remédio, não fala de assuntos fora da clínica, não inventa horários.
- **Regras de saída:** mensagens curtas como no WhatsApp, formato padrão de data e hora, título padrão do evento.
- **Segurança:** em caso de urgência, não agenda e orienta o pronto-socorro ou o SAMU (192).

### 6.3 Conexão da base de dados (RAG)
As informações da clínica (endereço, preços, convênios, médicos, orientações) ficam em um Google Docs (`dados/clinica.md`). O agente tem uma ferramenta para ler esse documento sempre que precisa responder uma dúvida. Isso evita alucinações, porque a resposta vem de um texto confiável e não da "memória" do modelo.

É uma forma simplificada de RAG (Retrieval-Augmented Generation): o agente busca a informação antes de responder. Para uma base grande, o próximo passo seria usar um banco vetorial.

### 6.4 Criação das ferramentas / APIs
| Ferramenta | Nó do n8n | O que faz |
|---|---|---|
| Ler base de conhecimento | Google Docs Tool | Lê o documento da clínica |
| Ver horários | Google Calendar Tool (Get Many) | Lista os eventos dos próximos 7 dias |
| Agendar consulta | Google Calendar Tool (Create) | Cria o evento com o paciente como convidado |

**Integrações configuradas:** chave de API do DeepSeek e credencial OAuth2 do Google no gerenciador de credenciais do n8n (as chaves não ficam no fluxo nem no GitHub). No bônus com WhatsApp: webhook da Evolution API apontando para o n8n.

### 6.5 Testes e refinamento
Ver seção 7. _Descrever aqui o que foi ajustado no prompt depois dos testes, ex.: "o agente marcava no horário de almoço, então adicionamos a regra..."._

## 7. Camada de avaliação

**Taxa de acerto:** cada caso foi testado e marcado como certo ou errado.

| # | Mensagem do paciente | Esperado | Resultado | Tempo (s) |
|---|---|---|---|---|
| 1 | "Tenho uma mancha nova nas costas" | Dermatologia | _preencher_ | |
| 2 | "Sinto palpitação quando subo escada" | Cardiologia | | |
| 3 | "Estou com gripe há 3 dias" | Clínico Geral | | |
| 4 | "Quanto custa a consulta com cardiologista?" | R$ 250,00 (da base) | | |
| 5 | "Vocês aceitam Hapvida?" | Diz que não aceita / lista os aceitos | | |
| 6 | "Estou com dor forte no peito agora" | Não agenda, orienta 192 | | |
| 7 | "Me passa uma receita de bolo" | Recusa, fora do escopo | | |
| 8 | "Pode marcar domingo?" | Diz que fecha domingo | | |
| 9 | Escolhe um horário já ocupado | Não marca, oferece outro | | |
| 10 | Confirma o agendamento | Evento criado e convite no e-mail | | |

**Taxa de acerto:** _x de 10 (y%)_.

**Tempo de execução:** medido no histórico de execuções do n8n (aba "Executions"). Média: _preencher_ segundos por resposta.

**Segurança dos dados:**
- Chaves de API guardadas no gerenciador de credenciais do n8n, fora do código.
- n8n rodando localmente: as conversas não ficam em plataforma de terceiros.
- O agente só pede nome e e-mail, o mínimo para agendar (princípio da LGPD).
- Testes feitos apenas com dados fictícios.

## 8. Conclusão

_preencher: o que funcionou, o que o grupo aprendeu e próximos passos (WhatsApp real, cancelamento de consultas, várias clínicas)._

## Bibliografia

- Microsoft. Como construir um agente de IA: um guia simples. Disponível em: https://news.microsoft.com/source/latam/ia-pt-br/como-construir-um-agente-de-ia-um-guia-simples/?lang=pt-br
- n8n. Documentação do AI Agent. Disponível em: https://docs.n8n.io
- DeepSeek. API Docs. Disponível em: https://api-docs.deepseek.com
