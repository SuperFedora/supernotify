// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

mod cast;
mod state;
mod tui;

use crate::cast::{CAST_ROSTER, animate_cast_cli, print_roster, sync_cast_assets, trigger_banner, trigger_cast};
use crate::state::{NotifyEnv, load_notifs, qs_call, qs_running, save_notifs};
use crate::tui::run_tui;
use std::env;
use std::io::{self, IsTerminal};
use std::process::{self, Command};

fn print_help() {
    println!("SuperNotify v0.1.0 — Standalone 16-Bit Animated Cast Comms & Arcade Banner Engine");
    println!("Usage:");
    println!("  supernotify                                           Launch interactive 16-Bit Cast & Banner TUI");
    println!("  supernotify tui                                       Launch interactive 16-Bit Cast & Banner TUI");
    println!("  supernotify status                                    Show daemon status, DND, unread & Cast Roster");
    println!("  supernotify cast [role|all|list]                      Show 10-specialist Cast Roster or trigger Cast Comms");
    println!("  supernotify animate [role] [--frames N]               Preview multi-frame 16-bit terminal sprite animation");
    println!("  supernotify --cast <role|all> [title] [body]          Trigger 16-bit animated character comms popup");
    println!("  supernotify --banner <ready|warning|update|checkpoint> [subtitle] Trigger 16-bit center screen banner");
    println!("  supernotify history                                   List notification history from Center");
    println!("  supernotify dnd [on|off|toggle|status]                Get, set, or toggle Do Not Disturb");
    println!("  supernotify clear | dismiss | center                  Manage active toasts & Notification Center");
    println!("  supernotify send <title> [body]                       Send desktop notification via notify-send");
    println!("  supernotify sync-cast                                 Sync all 10 animated SVG cast portraits to ~/.config/superfedora/cast/");
}

fn main() {
    let env = NotifyEnv::load();
    let _ = sync_cast_assets(&env);
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
            println!("supernotify 0.1.0 (SuperFedora/supernotify — Rust 1.99 Native Engine)");
        }
        "status" => {
            println!("  [OK] Notification Server : {}", if qs_running() { "running (quickshell)" } else { "offline" });
            println!("  [OK] Do Not Disturb      : {}", if st.dnd { "on" } else { "off" });
            println!("  [OK] Sprite Animations   : {}", if st.animations { "enabled (SVG + 60fps Canvas)" } else { "paused" });
            println!("  [OK] Unread in Center    : {}", st.history.len());
            println!("  [OK] Cast Roster         : {} animated 16-bit specialists ({})", CAST_ROSTER.len(), env.state_dir.join("cast").display());
        }
        "roster" | "characters" | "roles" => {
            print_roster(&env);
        }
        "animate" | "--animate" => {
            let role = args.get(1).map(|s| s.as_str()).unwrap_or("ai");
            let frames = args.windows(2).find(|w| w[0] == "--frames" || w[0] == "-f")
                .and_then(|w| w[1].parse::<usize>().ok())
                .or_else(|| args.get(2).and_then(|x| x.parse::<usize>().ok()))
                .unwrap_or(4);
            process::exit(animate_cast_cli(role, frames));
        }
        "sync-cast" | "sync" => {
            let n = sync_cast_assets(&env);
            println!("  [OK] Synced {n} animated 16-bit SVG cast portraits to {}", env.state_dir.join("cast").display());
        }
        "history" | "list" => {
            println!("SuperFedora Notification History (DND: {}, Unread: {})", if st.dnd { "on" } else { "off" }, st.history.len());
            if st.history.is_empty() {
                println!("  [--] No unread notifications in history.");
            } else {
                for (i, item) in st.history.iter().enumerate() {
                    let t = item.get("time").and_then(|v| v.as_str()).unwrap_or("--:--");
                    let urg = item.get("urgency").and_then(|v| v.as_str()).unwrap_or("normal").to_uppercase();
                    let role = item.get("roleTitle").or_else(|| item.get("role")).and_then(|v| v.as_str()).unwrap_or("SYS ENG").to_uppercase();
                    let app = item.get("appName").and_then(|v| v.as_str()).unwrap_or("System");
                    let s = item.get("summary").and_then(|v| v.as_str()).unwrap_or("Notification");
                    let b = item.get("body").and_then(|v| v.as_str()).unwrap_or("").replace('\n', " ");
                    let sfx = if b.trim().is_empty() { String::new() } else { format!(" — {}", b.trim()) };
                    println!("  [{:02}] {t} [{role} // {app}] ({urg}): {s}{sfx}", i + 1);
                }
            }
        }
        "--banner" | "banner" => {
            process::exit(trigger_banner(args.get(1).map(|s| s.as_str()).unwrap_or("ready"), args.get(2).map(|s| s.as_str())));
        }
        "--cast" | "cast" | "character" | "role" => {
            let sub = args.get(1).map(|s| s.as_str());
            if sub.is_none() || matches!(sub, Some("list" | "roster" | "roles")) {
                print_roster(&env);
                if action == "--cast" || sub.is_none() {
                    let _ = trigger_cast("all", None, None);
                }
                process::exit(0);
            }
            process::exit(trigger_cast(sub.unwrap_or("all"), args.get(2).map(|s| s.as_str()), args.get(3).map(|s| s.as_str())));
        }
        "test" | "preview" | "demo" => {
            let tgt = args.get(1).map(|s| s.as_str()).unwrap_or("all");
            if matches!(tgt.to_ascii_lowercase().as_str(), "ready" | "warn" | "warning" | "update" | "checkpoint") {
                process::exit(trigger_banner(tgt, None));
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
            let title = args.get(1).map(|s| s.as_str()).unwrap_or("SuperFedora");
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
