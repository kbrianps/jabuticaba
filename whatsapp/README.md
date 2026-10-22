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
