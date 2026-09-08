fn main() {
    // Server settings belong to the branded client build, not to a user-editable
    // configuration file. Store them as encoded bytes so a casual string search
    // of the executable does not reveal the deployment endpoints.
    fn obfuscated_function(env_name: &str, function_name: &str) -> String {
        let value = std::env::var(env_name).unwrap_or_default();
        let bytes: Vec<u8> = value
            .bytes()
            .enumerate()
            .map(|(index, byte)| byte ^ 0xA7u8.wrapping_add(index as u8).rotate_left(1))
            .collect();
        format!(
            "pub fn {function_name}() -> String {{\n    const DATA: &[u8] = &{:?};\n    String::from_utf8(DATA.iter().enumerate().map(|(index, byte)| byte ^ 0xA7u8.wrapping_add(index as u8).rotate_left(1)).collect()).expect(\"invalid iRidiDesk build configuration\")\n}}\n",
            bytes
        )
    }

    let generated = [
        obfuscated_function("IRIDI_RENDEZVOUS_SERVER", "iridi_rendezvous_server"),
        obfuscated_function("IRIDI_RELAY_SERVER", "iridi_relay_server"),
        obfuscated_function("IRIDI_API_SERVER", "iridi_api_server"),
        obfuscated_function("IRIDI_PUB_KEY", "iridi_pub_key"),
    ]
    .join("\n");
    let build_config = std::path::PathBuf::from(std::env::var("OUT_DIR").unwrap())
        .join("iridi_build_config.rs");
    std::fs::write(build_config, generated).expect("write iRidiDesk build configuration");
    for name in [
        "IRIDI_RENDEZVOUS_SERVER",
        "IRIDI_RELAY_SERVER",
        "IRIDI_API_SERVER",
        "IRIDI_PUB_KEY",
    ] {
        println!("cargo:rerun-if-env-changed={name}");
    }

    let out_dir = format!("{}/protos", std::env::var("OUT_DIR").unwrap());

    std::fs::create_dir_all(&out_dir).unwrap();

    protobuf_codegen::Codegen::new()
        .pure()
        .out_dir(out_dir)
        .inputs(["protos/rendezvous.proto", "protos/message.proto"])
        .include("protos")
        .customize(protobuf_codegen::Customize::default().tokio_bytes(true))
        .run()
        .expect("Codegen failed.");
}
