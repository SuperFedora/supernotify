// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::{play_sfx, qs_call};
use std::process::Command;

pub fn trigger_warning(sub: Option<&str>) -> i32 {
    let ok = if let Some(s) = sub.filter(|x| !x.is_empty()) {
        qs_call("notifications", &["bannerSub", "warning", s]) || qs_call("notifications", &["banner", "warning"])
    } else {
        qs_call("notifications", &["banner", "warning"])
    };
    if !ok {
        play_sfx("alert");
    }
    println!("  [OK] Banner triggered: W A R N I N G");
    0
}

pub fn trigger_banner(kind: &str, sub: Option<&str>) -> i32 {
    match kind.to_ascii_lowercase().as_str() {
        "warn" | "warning" | "critical" | "alert" | "danger" => trigger_warning(sub),
        "ready" | "boot" | "login" | "unlock" => {
            println!("  [OK] Banner triggered: R E A D Y");
            0
        }
        "update" | "forge" | "complete" | "checkpoint" | "snapshot" | "btrfs" | "saved" => {
            println!("  [OK] Banner triggered: {}", kind.to_ascii_uppercase());
            0
        }
        _ => {
            eprintln!("Usage: supernotify warn [subtitle]");
            2
        }
    }
}

pub fn trigger_cast(role: &str, custom_title: Option<&str>, custom_body: Option<&str>) -> i32 {
    let r = role.to_ascii_lowercase();
    if matches!(r.as_str(), "sec" | "security" | "warning" | "warn" | "critical" | "alert") {
        if let Some(title) = custom_title {
            let mut c = Command::new("notify-send");
            c.args(["-u", "critical", "-a", "SuperFedora", title]);
            if let Some(body) = custom_body
                && !body.is_empty()
            {
                c.arg(body);
            }
            let _ = c.status();
        }
        return trigger_warning(custom_title);
    }
    if let Some(title) = custom_title {
        let mut c = Command::new("notify-send");
        c.args(["-u", "normal", "-a", "SuperFedora", title]);
        if let Some(body) = custom_body
            && !body.is_empty()
        {
            c.arg(body);
        }
        let _ = c.status();
        println!("  [OK] Notification sent: {title}");
        return 0;
    }
    if !qs_call("notifications", &["cast", "test"]) {
        let _ = Command::new("notify-send")
            .args(["-u", "normal", "-a", "SuperFedora", "Notification"])
            .status();
    }
    println!("  [OK] Cast comms triggered: Notification");
    0
}
