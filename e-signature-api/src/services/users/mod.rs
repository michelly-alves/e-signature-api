// 1. Declara o arquivo `services.rs` como um submódulo público.
pub mod models;
pub mod services;

// 2. Re-exporta todas as funções públicas de `services.rs` para que
//    sejam acessíveis diretamente através de `crate::services::users::*`
pub use services::*;
