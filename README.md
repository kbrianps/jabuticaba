# Jabuticaba

Agente de IA que atende as clientes de um salão de beleza por chat (WhatsApp), indica o serviço certo e marca o horário no Google Agenda.

Trabalho de ACSO (Sistemas Autônomos, FAETEC), tema **"Criando um agente autônomo de IA"**. Entrega até **24/10**, grupo de até 4 alunos. Tema escolhido do roteiro do professor: **Agente de Agendamento por WhatsApp**, com a triagem e o pré-agendamento do Tema 3 aplicados a um salão de beleza fictício, o Salão Jabuticaba.

## O que o professor pede

**Entregáveis**
- [ ] Vídeo mostrando o agente funcionando
- [ ] Apresentação em PowerPoint
- [ ] Documento Word com o diagrama de operações e a descrição

**O que o documento precisa ter** (rascunho pronto em [docs/relatorio.md](docs/relatorio.md))
- [ ] Escopo do problema real e restrito
- [ ] Objetivos gerais e específicos
- [ ] Justificativa da pilha tecnológica
- [ ] Tipo de abordagem: no-code vs. low-code, com vantagens, desvantagens e justificativa
- [ ] Etapas: Definição do Problema, Prompt Base, Base de Dados (RAG), Ferramentas/APIs, Testes e Refinamento
- [ ] Engenharia de prompt: papel, limites e regras de saída
- [ ] Alimentação de dados
- [ ] Configuração das integrações (webhooks, chaves de API)
- [ ] Camada de avaliação: taxa de acerto, tempo de execução, segurança dos dados
- [ ] Diagrama de blocos: Interface (Chat) → Cérebro (LLM) → Tomada de Decisão → Execução da Ferramenta

## O que o agente faz

1. A cliente escreve no chat: "quero cobrir meus fios brancos, tem horário sábado?".
2. O agente faz a triagem: entende que é Coloração, com a Juliana, 2 horas, R$ 180.
3. Se for a primeira química, ele avisa do teste de alergia 48 horas antes.
4. Ele consulta os horários livres da semana no Google Agenda e oferece opções que caibam na duração do serviço.
5. Quando a cliente confirma, ele cria o evento e o Google envia o convite por e-mail.

## Arquitetura

```mermaid
flowchart LR
    U[Cliente<br/>Chat / WhatsApp] --> N[n8n<br/>AI Agent]
    N --> L[Cérebro<br/>DeepSeek]
    L --> D{Tomada de decisão}
    D -- dúvida ou triagem --> K[Base de conhecimento<br/>dados/salao.md]
    D -- ver horários --> G1[Google Agenda<br/>horários livres]
    D -- confirmar --> G2[Google Agenda<br/>criar evento + convite]
    N --> U
```

| Peça | Para que serve | Custo |
|---|---|---|
| **n8n** | Monta o agente arrastando blocos (low-code) | Grátis (self-hosted) |
| **DeepSeek** | O cérebro: entende a mensagem e decide qual ferramenta usar | Centavos |
| **Google Agenda** | Ver horários livres e criar o atendimento com convite por e-mail | Grátis |
| **Evolution API** | Liga um número de WhatsApp ao n8n | Grátis (opcional, ver abaixo) |
| **Docker** | Roda o n8n (e a Evolution) no PC com um comando | Grátis |

## Plano para os 3 dias

O Tema 3 do professor aceita "simular um chat de WhatsApp". Por isso o plano usa primeiro o **chat do próprio n8n**, que já funciona sem configurar nada. O WhatsApp de verdade fica como bônus se sobrar tempo.

### Dia 1 (21–22/10): agente conversando
1. Instalar o Docker Desktop e subir o n8n: `docker run -it --rm -p 5678:5678 -v n8n_data:/home/node/.n8n docker.n8n.io/n8nio/n8n` e abrir `http://localhost:5678`.
2. Criar conta na DeepSeek, colocar uns poucos reais de crédito e gerar a chave de API.
3. No n8n: bloco **When chat message received** → bloco **AI Agent** com modelo **DeepSeek Chat** e **Simple Memory**.
4. Colar o prompt de [prompts/prompt-base.md](prompts/prompt-base.md) no campo "System Message" do AI Agent.
5. Conversar pelo botão "Open chat" e ver a triagem funcionando.

**Aprende:** o que é LLM, prompt, token, memória e por que a IA "alucina".

### Dia 2 (22–23/10): ferramentas
1. Criar uma agenda "Salão Jabuticaba" no Google Agenda e ligar a conta Google no n8n.
2. Adicionar no AI Agent duas ferramentas **Google Calendar Tool**: uma para ver eventos da semana (horários ocupados) e outra para criar evento com o e-mail da cliente como convidada.
3. Criar um Google Docs com o texto de [dados/salao.md](dados/salao.md) e adicionar a ferramenta **Google Docs Tool** para ler esse documento (é a nossa base de conhecimento, um RAG simplificado).
4. Testar os casos da tabela em [docs/relatorio.md](docs/relatorio.md#7-camada-de-avaliação) e anotar os resultados.

**Aprende:** a diferença entre chatbot e agente: o agente decide sozinho quando usar cada ferramenta.

### Dia 3 (23–24/10): entrega
1. Gravar o vídeo (2 a 3 minutos): mostrar o fluxo no n8n, uma conversa completa e o evento aparecendo na agenda e o convite no e-mail.
2. Completar [docs/relatorio.md](docs/relatorio.md) com os resultados dos testes e passar para o Word com prints.
3. Montar o PowerPoint usando as mesmas seções do relatório.

### Bônus: WhatsApp de verdade
Subir a Evolution API, ler o QR Code com um chip de teste, apontar o webhook para o n8n e trocar o gatilho de chat por um **Webhook** + **HTTP Request** para responder. Use um número de teste: a Evolution usa o WhatsApp Web, que não é a API oficial, e o número pode ser bloqueado.

## Pensando em produto (depois do trabalho)

A mesma base serve para vender um "atendente automático" para salões, barbearias, estúdios de unha e clínicas de estética: um número de WhatsApp, uma agenda e uma base de conhecimento por cliente, rodando em um servidor barato.

## Cuidados

- Nunca suba chaves de API para o GitHub.
- Não use dados reais de clientes nos testes.
