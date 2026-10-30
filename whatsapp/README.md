# WhatsApp com a Evolution API

A Evolution API liga um número de WhatsApp ao n8n. Ela roda no seu computador com Docker, e um túnel da Cloudflare dá a ela um endereço público para o n8n Cloud conseguir responder.

```
WhatsApp do cliente → Evolution (seu PC) → n8n Cloud (agente) → túnel → Evolution → WhatsApp do cliente
```

- **Número do agente:** o WhatsApp que vai ler o QR Code (21 97181-7100).
- **Número de teste:** o único que o agente responde (21 98811-1260). Fica no campo `numero_teste` do Config, no formato `5521988111260`. Isso evita que o agente responda os contatos pessoais do número.
- **Fluxo no n8n:** "Agente WhatsApp (Jabuticaba)". O fluxo do chat continua igual, para o vídeo.

> A Evolution usa o WhatsApp Web, que não é a API oficial. Existe risco de o número ser bloqueado se mandar muitas mensagens. Para o trabalho, use poucas conversas.

## 1. Subir a Evolution no computador

1. Instale o [Docker Desktop](https://www.docker.com/products/docker-desktop/) e deixe ele aberto.
2. Baixe esta pasta `whatsapp` do GitHub.
3. Copie o arquivo `.env.example` e renomeie a cópia para `.env`.
4. No `.env`, troque `AUTHENTICATION_API_KEY` por uma senha grande, só com letras e números. Guarde essa senha.
5. Abra o terminal (PowerShell) dentro da pasta e rode:

```
docker compose up -d
```

6. Veja o endereço público do túnel:

```
docker compose logs tunel
```

Procure uma linha com `https://alguma-coisa.trycloudflare.com` e copie esse endereço.

## 2. Ligar o número do agente

1. Abra http://localhost:8080/manager no navegador.
2. Entre com a senha do `AUTHENTICATION_API_KEY`.
3. Clique em **Instance** (+), dê o nome `jabuticaba`, escolha **Baileys** e salve.
4. Abra a instância e clique em **Get QR Code**.
5. No celular do 97181-7100: WhatsApp → **Aparelhos conectados** → **Conectar um aparelho** → leia o QR Code.

O status muda para **Connected**.

## 3. Configurar o n8n

No fluxo **Agente WhatsApp (Jabuticaba)**:

1. **Config:** cole o endereço do túnel em `evolution_url`, sem barra no final.
2. **Responder no WhatsApp:** em Credential, crie uma nova do tipo **Header Auth**:
   - Name: `apikey`
   - Value: a mesma senha do `AUTHENTICATION_API_KEY`
3. Clique em **Publish** para ativar o fluxo.

## 4. Testar

Do celular 98811-1260, mande "oi" para o 97181-7100. A Jabu deve responder em poucos segundos. Em **Executions** dá para ver cada passo.

## Problemas comuns

| O que acontece | O que fazer |
|---|---|
| O agente não responde | Veja em Executions se o fluxo rodou. Se parou em "Só o número de teste", abra o nó e confira o campo `numero`. |
| Erro 401 em "Responder no WhatsApp" | A senha da credencial está diferente da do `.env`. |
| Erro de conexão em "Responder no WhatsApp" | O endereço do túnel mudou. Ele muda toda vez que o Docker reinicia: rode `docker compose logs tunel` e atualize o Config. |
| O QR Code não aparece | Rode `docker compose restart evolution` e tente de novo. |
| Desligar tudo | `docker compose down` (a conexão do WhatsApp fica salva). |

## n8n local (grátis)

O mesmo `docker-compose.yml` também sobe o n8n self-hosted (imagem oficial `docker.n8n.io/n8nio/n8n`), na mesma rede da Evolution. Assim a Evolution chama o n8n pelo nome `n8n`, sem túnel.

- Subir tudo: `docker compose up -d`. Só o n8n: `docker compose up -d n8n`.
- Parar: `docker compose stop n8n` (ou `docker compose down` para tudo). Os fluxos ficam salvos no volume `n8n_data`.
- Abrir: http://localhost:5678. No primeiro acesso, crie a conta de dono local (fica só no seu computador).
- No `.env`, use `WEBHOOK_GLOBAL_URL=http://n8n:5678/webhook/jabuticaba-whatsapp` para a Evolution mandar as mensagens para o n8n local.
- No fluxo, o campo `evolution_url` do Config passa a ser `http://evolution:8080` (sem túnel).

## Dados do salão no Supabase

O fluxo local não guarda mais os dados do salão no Config. A cada mensagem, o nó **Buscar salão** chama a função `contexto_salao` do Supabase com o nome da instância da Evolution (`jabuticaba`), e o nó **Montar contexto** monta o texto que o agente usa (profissionais, serviços, preços, políticas e agenda).

- Banco: rode no SQL Editor do Supabase, nesta ordem, `banco/schema.sql`, `banco/funcoes-agente.sql` e `banco/dados-jabuticaba.sql`. Em um banco que já existe, basta rodar `banco/funcoes-agente.sql` e depois `banco/dados-jabuticaba.sql` (ele não duplica nada e só ajusta o prazo de 24 horas).
- Credencial no n8n: crie uma do tipo **Supabase API** com o Host `https://dhtumvumreirkterjwak.supabase.co` e a chave **service_role** (Project Settings → API Keys). Selecione essa credencial no nó **Buscar salão**.
- Salão novo: cadastre uma linha em `saloes` com `evolution_instancia` igual ao nome da instância criada na Evolution, mais os profissionais e serviços. O fluxo não muda.
- Agenda: o campo `calendar_id` do salão diz qual Google Agenda usar. A conta Google da credencial precisa ter acesso a essa agenda.
- Clientes: na primeira mensagem o cliente é cadastrado pelo número. Quando ele diz o nome e o e-mail, o agente salva (`salvar_cliente`) e não pergunta de novo nas próximas vezes.
- Agendamentos: cada horário criado na Google Agenda também é gravado na tabela `agendamentos` (`registrar_agendamento`). O cliente pode remarcar ou cancelar pelo WhatsApp, e o agente só mexe nos agendamentos dele mesmo.
- Horário ocupado: o banco não aceita dois agendamentos marcados no mesmo horário com o mesmo profissional. Antes de criar ou remarcar, o agente confere com `conferir_horario` (função `horario_livre`).
- Prazo para mudar: `saloes.antecedencia_minima_horas` diz até quantas horas antes do horário o cliente pode cancelar ou remarcar pelo WhatsApp (0 = sem limite; no Jabuticaba é 24). Fora do prazo, o agente não muda e oferece chamar a equipe.
- Chamar a equipe: quando o cliente pede uma pessoa, o agente manda uma mensagem para o número em `saloes.whatsapp_responsavel` (formato `5521999999999`) e fica 12 horas sem responder esse cliente. Para o agente voltar antes, apague o valor de `humano_ate` do cliente na tabela `clientes`.

## Lembretes

O fluxo `n8n/lembretes-local.json` roda todo dia às 18h e manda pelo WhatsApp um lembrete para quem tem horário no dia seguinte. Ele usa as mesmas credenciais (Supabase API e Header Auth) e, por enquanto, só envia para o `numero_teste` do Config.
