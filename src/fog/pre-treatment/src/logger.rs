use env_logger::Builder;
use log::LevelFilter;
use std::io::Write;

pub fn setup_logger(log_thread: bool, rust_log: Option<&String>) {
    let mut builder = Builder::new();

    // Default to info if not specified
    let filter_level = rust_log
        .map(|s| s.as_str())
        .unwrap_or("info")
        .parse::<LevelFilter>()
        .unwrap_or(LevelFilter::Info);

    builder.filter_level(filter_level);

    // Simplified format to avoid version compatibility issues with env_logger::fmt::Color
    builder.format(move |buf, record| {
        let thread_name = if log_thread {
            format!(" [{:?}]", std::thread::current().id())
        } else {
            "".to_string()
        };

        writeln!(
            buf,
            "{} {}{}: {}",
            buf.timestamp(),
            record.level(),
            thread_name,
            record.args()
        )
    });

    builder.init();
}
