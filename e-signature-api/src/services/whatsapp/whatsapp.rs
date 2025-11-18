use reqwest::Client;
use std::env;
use std::error::Error;

pub async fn send_otp_via_whatsapp(to_number: &str, otp_code: &str) -> Result<(), Box<dyn Error>> {
    let account_sid =
        env::var("TWILIO_ACCOUNT_SID").expect("TWILIO_ACCOUNT_SID deve estar definido");
    let auth_token = env::var("TWILIO_AUTH_TOKEN").expect("TWILIO_AUTH_TOKEN deve estar definido");
    let from_number = "whatsapp:+14155238886"; 

    let url = format!(
        "https://api.twilio.com/2010-04-01/Accounts/{}/Messages.json",
        account_sid
    );

    let to_formatted = format!("whatsapp:{}", to_number);

    let client = Client::new();

    let params = [
        ("To", to_formatted),
        ("From", from_number.to_string()),
        (
            "Body",
            format!("Seu código de verificação e-Signature é: {}", otp_code),
        ),
    ];

    let response = client
        .post(&url)
        .basic_auth(account_sid, Some(auth_token))
        .form(&params)
        .send()
        .await?;

    if response.status().is_success() {
        println!("Mensagem de WhatsApp enviada para {}", to_number);
        Ok(())
    } else {
        let error_text = response.text().await?;
        println!("Erro ao enviar WhatsApp: {}", error_text);
        Err(format!("Falha no envio: {}", error_text).into())
    }
}
