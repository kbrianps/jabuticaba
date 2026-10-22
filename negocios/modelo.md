# Configuração: modelo para um novo negócio

Copie este arquivo, preencha e cole cada valor no campo de mesmo nome do nó **Config** no n8n. O fluxo e o prompt não mudam.

Veja [salao.md](salao.md) como exemplo preenchido.

## Campos curtos

| Campo | Valor |
|---|---|
| nome_negocio | ex.: Barbearia do Zé |
| nome_assistente | ex.: Zé Bot |
| tipo_negocio | ex.: barbearia, estúdio de unhas, clínica de estética, personal trainer |
| tom | ex.: descontraído / formal e educado |
| fuso | America/Sao_Paulo |

## base_conhecimento

```
SOBRE
Endereço:
Telefone:
Funcionamento:
Pausas (almoço):

PROFISSIONAIS
- Nome: o que faz. Dias de atendimento.

SERVIÇOS (duração, preço, profissional)
- Serviço: duração, preço, profissional

GUIA PARA A TRIAGEM
- "Como o cliente costuma pedir": Serviço

POLÍTICAS
- Atraso, cancelamento, formas de pagamento
```

## regras_especificas

```
- Regras que só valem para este negócio (segurança, pré-requisitos, restrições).
```
