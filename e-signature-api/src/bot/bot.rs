use dotenv::dotenv;
use dptree;
use reqwest::Client;
use serde_json::json;
use std::env;
use teloxide::{
    dispatching::Dispatcher,
    prelude::*,
    requests::ResponseResult,
    types::{Message, Update},
    utils::command::BotCommands,
};

#[derive(BotCommands, Clone)]
#[command(rename_rule = "lowercase", description = "Comandos disponíveis:")]
enum Command {
    #[command(description = "Inicia o bot e confirma o link Telegram.")]
    Start(String),
}

pub async fn run_bot() {
    dotenv().ok();
    let bot_token = env::var("TELEGRAM_BOT_TOKEN").expect("TELEGRAM_BOT_TOKEN not set");
    let api_url = env::var("API_BASE_URL").expect("API_BASE_URL not set");

    let bot = Bot::new(bot_token);

    let command_handler = Update::filter_message()
        .filter_command::<Command>()
        .endpoint(move |bot, msg, cmd| handle_command(bot, msg, cmd, api_url.clone()));

    Dispatcher::builder(bot, command_handler)
        .dependencies(dptree::deps![])
        .enable_ctrlc_handler()
        .build()
        .dispatch()
        .await;
}

async fn handle_command(
    bot: Bot,
    msg: Message,
    cmd: Command,
    api_url: String,
) -> ResponseResult<()> {
    match cmd {
        Command::Start(link_token) => {
            let chat_id = msg.chat.id;

            if link_token.is_empty() {
                bot.send_message(
                    chat_id,
                    "Olá! Para vincular sua conta, acesse o painel e clique em *Conectar Telegram*.",
                )
                .parse_mode(teloxide::types::ParseMode::MarkdownV2)
                .await?;
                return Ok(());
            }

            let client = Client::new();

            let confirm_url = format!("{}/telegram/confirm", api_url);
            let resp = client
                .post(&confirm_url)
                .json(&json!({ "token": link_token, "chat_id": chat_id }))
                .send()
                .await;

            let resp_json = match resp {
                Ok(r) if r.status().is_success() => r.json::<serde_json::Value>().await.ok(),
                Ok(r) => {
                    let body = r.text().await.unwrap_or_default();
                    bot.send_message(chat_id, format!("❌ Erro ao confirmar link: {}", body))
                        .await?;
                    return Ok(());
                }
                Err(e) => {
                    bot.send_message(chat_id, format!("Erro de comunicação: {}", e))
                        .await?;
                    return Ok(());
                }
            };

            let user_jwt = match resp_json
                .as_ref()
                .and_then(|v| v.get("jwt").and_then(|j| j.as_str()))
            {
                Some(jwt) => jwt.to_string(),
                None => {
                    bot.send_message(
                        chat_id,
                        "⚠️ JWT do usuário não disponível. OTP não pode ser gerado.",
                    )
                    .await?;
                    return Ok(());
                }
            };

            bot.send_message(chat_id, "✅ Seu Telegram foi vinculado com sucesso!")
                .await?;
            get_user_and_generate_otp(&client, &api_url, &user_jwt, chat_id, &bot).await?;
        }
    }

    Ok(())
}

async fn get_user_and_generate_otp(
    client: &Client,
    api_url: &str,
    user_jwt: &str,
    chat_id: teloxide::types::ChatId,
    bot: &Bot,
) -> ResponseResult<()> {
    let me_url = format!("{}/api/users/me", api_url);
    let user_resp = client.get(&me_url).bearer_auth(user_jwt).send().await;

    let user_json = match user_resp {
        Ok(r) if r.status().is_success() => r.json::<serde_json::Value>().await.ok(),
        Ok(r) => {
            let body = r.text().await.unwrap_or_default();
            bot.send_message(chat_id, format!("❌ Erro ao recuperar usuário: {}", body))
                .await?;
            return Ok(());
        }
        Err(e) => {
            bot.send_message(chat_id, format!("Erro de comunicação: {}", e))
                .await?;
            return Ok(());
        }
    };

    if let Some(user) = user_json {
        if let Some(email) = user["email"].as_str() {
            let otp_url = format!("{}/otp/generate", api_url);
            bot.send_message(chat_id, "🔐 Gerando seu código OTP...")
                .await?;

            match client
                .post(&otp_url)
                .json(&json!({ "email": email }))
                .send()
                .await
            {
                Ok(resp) => match resp.json::<serde_json::Value>().await {
                    Ok(json) => {
                        if let Some(code) = json["otp"].as_str() {
                            bot.send_message(chat_id, format!("🔑 Seu código OTP é: {}", code))
                                .parse_mode(teloxide::types::ParseMode::MarkdownV2)
                                .await?;
                        } else {
                            bot.send_message(chat_id, "Erro ao interpretar o código OTP.")
                                .await?;
                        }
                    }
                    Err(_) => {
                        bot.send_message(chat_id, "Erro ao processar resposta da API.")
                            .await?;
                    }
                },
                Err(_) => {
                    bot.send_message(chat_id, "Erro de comunicação com a API.")
                        .await?;
                }
            }
        }
    }

    Ok(())
}
