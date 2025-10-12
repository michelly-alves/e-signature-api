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
    #[command(description = "Inicia o  bot e envia o código OTP.")]
    Start,
}

pub async fn run_bot() {
    dotenv().ok();
    let bot_token = env::var("TELEGRAM_BOT_TOKEN").expect("TELEGRAM_BOT_TOKEN not set");
    let api_url = env::var("API_BASE_URL").expect("API_BASE_URL not set");

    let bot = Bot::new(bot_token);

    let command_handler = Update::filter_message()
        .filter_command::<Command>()
        .endpoint(handle_command);

    Dispatcher::builder(bot, command_handler)
        .dependencies(dptree::deps![api_url])
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
        Command::Start => {
            let chat_id = msg.chat.id;
            let email = "usuario@teste.com"; // Pode ser obtido dinamicamente

            let otp_url = format!("{}/otp/generate", api_url);
            let client = Client::new();

            bot.send_message(chat_id, "Gerando seu código OTP...")
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
                            bot.send_message(chat_id, format!("🔐 Seu código OTP é: `{}`", code))
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
