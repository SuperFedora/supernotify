// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

mod cast;
mod state;
mod tui;

use crate::cast::{trigger_banner, trigger_cast, trigger_warning};
use crate::state::{NotifyEnv, load_notifs, qs_call, qs_running, save_notifs};
use crate::tui::run_tui;
use std::env;
use std::io::{self, IsTerminal};
use std::process::{self, Command};

fn print_help() {
    println!("SuperNotify v0.5.0 — Notification & Full-Screen WARNING Controller");
    println!("Usage:");
    println!("  supernotify                                    Launch interactive Notification TUI");
    println!("  supernotify tui                                Launch interactive Notification TUI");
    println!("  supernotify status                             Show daemon status, DND & unread count");
    println!("  supernotify send <title> [body]                Send desktop notification");
    println!("  supernotify warn [subtitle]                    Trigger full-screen WARNING overlay");
    println!("  supernotify history                            List notification history");
    println!("  supernotify dnd [on|off|toggle|status]         Get, set, or toggle Do Not Disturb");
    println!("  supernotify clear | dismiss | center           Manage active toasts & Notification Center");
}

fn main() {
    let env = NotifyEnv::load();
    let args: Vec<String> = env::args().skip(1).collect();
    if args.is_empty() && io::stdin().is_terminal() && io::stdout().is_terminal() {
        process::exit(run_tui(&env));
    }
    let action = args.first().map(|s| s.as_str()).unwrap_or("status");
    let mut st = load_notifs(&env);

    if let Some(b) = action.strip_prefix("--banner=") {
        process::exit(trigger_banner(b, args.get(1).map(|s| s.as_str())));
    }
    if let Some(c) = action.strip_prefix("--cast=") {
        process::exit(trigger_cast(c, args.get(1).map(|s| s.as_str()), args.get(2).map(|s| s.as_str())));
    }

    match action {
        "tui" => process::exit(run_tui(&env)),
        "version" | "--version" | "-V" => {
            println!("supernotify 0.5.0");
        }
        "status" | "overlay" | "--overlay" => {
            println!(
                "  [OK] Notification Server : {}",
                if qs_running() { "running (quickshell)" } else { "offline" }
            );
            println!("  [OK] Do Not Disturb      : {}", if st.dnd { "on" } else { "off" });
            println!("  [OK] Unread              : {}", st.history.len());
        }
        "history" | "list" => {
            println!(
                "Notifications (DND: {}, Unread: {})",
                if st.dnd { "on" } else { "off" },
                st.history.len()
            );
            if st.history.is_empty() {
                println!("  [--] No unread notifications.");
            } else {
                for (i, item) in st.history.iter().enumerate() {
                    let t = item.get("time").and_then(|v| v.as_str()).unwrap_or("--:--");
                    let s = item.get("summary").and_then(|v| v.as_str()).unwrap_or("Notification");
                    let b = item.get("body").and_then(|v| v.as_str()).unwrap_or("").replace('\n', " ");
                    let sfx = if b.trim().is_empty() { String::new() } else { format!(" — {}", b.trim()) };
                    println!("  [{:02}] {t}  {s}{sfx}", i + 1);
                }
            }
        }
        "warn" | "--warn" | "warning" | "--warning" => {
            process::exit(trigger_warning(args.get(1).map(|s| s.as_str())));
        }
        "--banner" | "banner" => {
            process::exit(trigger_banner(
                args.get(1).map(|s| s.as_str()).unwrap_or("warning"),
                args.get(2).map(|s| s.as_str()),
            ));
        }
        "--cast" | "cast" | "character" | "role" | "roster" | "characters" | "roles" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("test");
            process::exit(trigger_cast(sub, args.get(2).map(|s| s.as_str()), args.get(3).map(|s| s.as_str())));
        }
        "test" | "preview" | "demo" => {
            let tgt = args.get(1).map(|s| s.as_str()).unwrap_or("test");
            if matches!(tgt.to_ascii_lowercase().as_str(), "warn" | "warning" | "critical" | "alert") {
                process::exit(trigger_warning(args.get(2).map(|s| s.as_str())));
            } else {
                process::exit(trigger_cast(tgt, None, None));
            }
        }
        "dnd" => {
            let sub = args.get(1).map(|s| s.as_str()).unwrap_or("toggle");
            if sub == "status" || sub == "get" {
                println!("{}", if st.dnd { "on" } else { "off" });
            } else if matches!(sub, "on" | "off" | "toggle") {
                st.dnd = if sub == "toggle" { !st.dnd } else { sub == "on" };
                save_notifs(&env, &st);
                let lbl = if st.dnd { "on" } else { "off" };
                let _ = qs_call("notifications", &["setDnd", lbl]);
                println!("  [OK] Do Not Disturb: {lbl}");
            } else {
                eprintln!("Usage: supernotify dnd [on|off|toggle|status]");
                process::exit(2);
            }
        }
        "clear" | "dismiss-all" | "dismissAll" => {
            st.history.clear();
            save_notifs(&env, &st);
            let _ = qs_call("notifications", &["dismissAll"]);
            println!("  [OK] Cleared all notifications.");
        }
        "dismiss" => {
            if !qs_call("notifications", &["dismiss"]) && !st.history.is_empty() {
                st.history.remove(0);
                save_notifs(&env, &st);
            }
            println!("  [OK] Dismissed latest notification.");
        }
        "center" | "toggle" => {
            let _ = qs_call("notifications", &["toggle"]);
            println!("  [OK] Toggled Notification Center.");
        }
        "send" => {
            let title = args.get(1).map(|s| s.as_str()).unwrap_or("Notification");
            let mut c = Command::new("notify-send");
            c.args(["-a", "SuperFedora", title]);
            if let Some(body) = args.get(2)
                && !body.is_empty()
            {
                c.arg(body);
            }
            let _ = c.status();
            println!("  [OK] Sent notification: {title}");
        }
        "-h" | "--help" | "help" => print_help(),
        _ => {
            eprintln!("unknown notify action: {action}");
            process::exit(2);
        }
    }
}
