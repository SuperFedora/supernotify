// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::state::{NotifyEnv, play_sfx, qs_call};
use std::fs;
use std::process::Command;

#[derive(Clone, Copy)]
pub struct CastMember {
    pub id: &'static str,
    pub key: char,
    pub role_title: &'static str,
    pub callsign: &'static str,
    pub zone: &'static str,
    pub urgency: &'static str,
    pub rgb: (u8, u8, u8),
    pub anim_style: &'static str,
    pub sample_title: &'static str,
    pub sample_body: &'static str,
    pub desc: &'static str,
}

pub const CAST_ROSTER: &[CastMember] = &[
    CastMember {
        id: "ai", key: '1', role_title: "AI AGENT", callsign: "AGY // OPENCLAW",
        zone: "bottom-center", urgency: "normal", rgb: (122, 162, 247),
        anim_style: "neural-pulse + visor-scan + talk-frames",
        sample_title: "Neural Harness Link Active",
        sample_body: "Context indexed. Ready for code synthesis and workstation automation.",
        desc: "AI Agent (Bottom-Center)",
    },
    CastMember {
        id: "security", key: '2', role_title: "SEC ALERT", callsign: "POLKIT // GUARD",
        zone: "top-center", urgency: "critical", rgb: (247, 118, 142),
        anim_style: "siren-strobe + hazard-pulse + talk-frames",
        sample_title: "Privilege Escalation Check",
        sample_body: "Critical telemetry & policy guard monitoring active on root subvolume.",
        desc: "Security / System Alert (Top-Center + WARNING Banner)",
    },
    CastMember {
        id: "builder", key: '3', role_title: "BUILDER", callsign: "SF FORGE",
        zone: "top-right", urgency: "normal", rgb: (158, 206, 106),
        anim_style: "welder-sparks + visor-glow + talk-frames",
        sample_title: "Native Target Compiled",
        sample_body: "Built with -O3 -march=native -flto=auto and linked via mold.",
        desc: "Builder / Forge (Top-Right)",
    },
    CastMember {
        id: "engineer", key: '4', role_title: "SYS ENG", callsign: "SUPERFEDORA",
        zone: "top-right", urgency: "normal", rgb: (125, 207, 255),
        anim_style: "hud-reticle + antenna-blink + talk-frames",
        sample_title: "Btrfs Checkpoint Verified",
        sample_body: "Workstation subvolume state synchronized and ready for rollback.",
        desc: "System Engineer (Top-Right)",
    },
    CastMember {
        id: "app", key: '5', role_title: "APP COMMS", callsign: "FIREFOX",
        zone: "top-right", urgency: "normal", rgb: (187, 154, 247),
        anim_style: "crt-scanline + signal-wave + talk-frames",
        sample_title: "External App Transmission",
        sample_body: "Incoming desktop application relay framed in 16-bit scanline bezel.",
        desc: "App Comms (Top-Right)",
    },
    CastMember {
        id: "navigator", key: '6', role_title: "NAVIGATOR", callsign: "NET // TAILSCALE",
        zone: "top-right", urgency: "normal", rgb: (42, 195, 222),
        anim_style: "radar-sweep + compass-pulse + talk-frames",
        sample_title: "Mesh Route Synchronized",
        sample_body: "Tailscale WireGuard tunnel & low-latency DNS routing locked.",
        desc: "Network Navigator (Top-Right)",
    },
    CastMember {
        id: "medic", key: '7', role_title: "SYS MEDIC", callsign: "BTRFS // HEALER",
        zone: "top-center", urgency: "normal", rgb: (115, 218, 202),
        anim_style: "ecg-heartbeat + cross-beacon + talk-frames",
        sample_title: "Subvolume Health Scrub",
        sample_body: "Thermal, SMART, and Btrfs scrub diagnostics verified with zero errors.",
        desc: "System Medic / Recovery (Top-Center)",
    },
    CastMember {
        id: "archivist", key: '8', role_title: "ARCHIVIST", callsign: "SNAPPER // VAULT",
        zone: "top-right", urgency: "normal", rgb: (224, 175, 104),
        anim_style: "data-scroll + monocle-glint + talk-frames",
        sample_title: "Immutable Snapshot Sealed",
        sample_body: "Timeline checkpoint indexed into cold storage and GRUB boot menu.",
        desc: "Data Archivist / Vault (Top-Right)",
    },
    CastMember {
        id: "commander", key: '9', role_title: "COMMANDER", callsign: "FLEET // OPS",
        zone: "top-center", urgency: "normal", rgb: (255, 158, 100),
        anim_style: "visor-sweep + chevron-pulse + talk-frames",
        sample_title: "Tactical Override Active",
        sample_body: "Workstation mission parameters locked across all active workspaces.",
        desc: "Fleet Commander (Top-Center)",
    },
    CastMember {
        id: "synth", key: '0', role_title: "AUDIO SYNTH", callsign: "PIPEWIRE // DSP",
        zone: "bottom-center", urgency: "normal", rgb: (255, 117, 195),
        anim_style: "eq-spectrum + wave-oscillator + talk-frames",
        sample_title: "16-Bit PCM Synth Locked",
        sample_body: "Low-latency PipeWire quantum 64/48000Hz and FM chiptune cues online.",
        desc: "Audio Synth / Media (Bottom-Center)",
    },
];

pub fn resolve_cast(role: &str) -> Option<&'static CastMember> {
    match role.to_ascii_lowercase().as_str() {
        "ai" | "agent" | "openclaw" | "agy" | "claude" | "ollama" | "pi" => Some(&CAST_ROSTER[0]),
        "sec" | "security" | "alert" | "polkit" | "firewall" | "critical" => Some(&CAST_ROSTER[1]),
        "build" | "builder" | "forge" | "dnf" | "cargo" | "gcc" => Some(&CAST_ROSTER[2]),
        "eng" | "engineer" | "sys" | "system" | "superfedora" | "btrfs" => Some(&CAST_ROSTER[3]),
        "app" | "apps" | "firefox" | "discord" | "slack" | "spotify" => Some(&CAST_ROSTER[4]),
        "nav" | "navigator" | "net" | "network" | "wifi" | "vpn" | "tailscale" => Some(&CAST_ROSTER[5]),
        "med" | "medic" | "healer" | "health" | "doctor" | "thermal" | "battery" => Some(&CAST_ROSTER[6]),
        "arch" | "archivist" | "vault" | "snapper" | "snapshot" | "backup" | "git" => Some(&CAST_ROSTER[7]),
        "cmd" | "commander" | "ops" | "fleet" | "tactical" | "mission" => Some(&CAST_ROSTER[8]),
        "syn" | "synth" | "audio" | "sfx" | "sound" | "pipewire" | "music" => Some(&CAST_ROSTER[9]),
        _ => None,
    }
}

pub fn sprite_lines(id: &str, frame: usize) -> [&'static str; 5] {
    let f = frame % 4;
    let blink = f == 3;
    let talk = f % 2 == 1;
    let eyes = if blink { " [--]  [--] " } else { " [██]  [██] " };
    let mouth = if talk { "  ╔══════╗  " } else { "  ╚══════╝  " };
    let (top, bot) = match id {
        "ai" => (if f % 2 == 0 { "  ╔══▲▲══╗  " } else { "  ╔══◊◊══╗  " }, " ╚═[NEURAL]═╝"),
        "security" => (if f % 2 == 0 { "  ╔═[!!]═╗  " } else { "  ╔═[**]═╗  " }, " ╚═[GUARD!]═╝"),
        "builder" => (if f % 2 == 0 { " *╔══════╗  " } else { "  ╔══════╗* " }, " ╚═[FORGE+]═╝"),
        "engineer" => ("  ╔══════╦° ", " ╚═[SYSENG]═╝"),
        "app" => ("  ╔══════╗  ", " ╚═[CRT//8]═╝"),
        "navigator" => (if f % 2 == 0 { "  ╔═[>>]═╗  " } else { "  ╔═[<<]═╗  " }, " ╚═[RADAR~]═╝"),
        "medic" => ("  ╔══╬╬══╗  ", " ╚═[HEALER]═╝"),
        "archivist" => ("  ╔══════╗  ", " ╚═[VAULT#]═╝"),
        "commander" => ("  ╔══▼▼══╗  ", " ╚═[CMD//1]═╝"),
        _ => (if f % 2 == 0 { " ♫╔══════╗♪ " } else { " ♪╔══════╗♫ " }, " ╚═[SYNTH~]═╝"),
    };
    [top, " ╔╣      ╠╗ ", eyes, mouth, bot]
}

pub fn sync_cast_assets(env: &NotifyEnv) -> usize {
    let dst_dir = env.state_dir.join("cast");
    let _ = fs::create_dir_all(&dst_dir);
    let src_dir = env.repo_root.join("cast");
    let mut count = 0usize;
    if let Ok(entries) = fs::read_dir(&src_dir) {
        for e in entries.flatten() {
            let p = e.path();
            if p.extension().and_then(|x| x.to_str()) == Some("svg")
                && let Some(name) = p.file_name()
            {
                let _ = fs::copy(&p, dst_dir.join(name));
                count += 1;
            }
        }
    }
    count
}

pub fn print_roster(env: &NotifyEnv) {
    let synced = sync_cast_assets(env);
    println!("SuperNotify v0.2.0 — 16-Bit Animated Workstation Cast Roster ({} Specialists, {} SVGs synced)", CAST_ROSTER.len(), synced);
    println!("  KEY  ID          ROLE         ZONE           CALLSIGN          ANIMATION PROFILE");
    println!("  ---  --          ----         ----           --------          -----------------");
    for m in CAST_ROSTER {
        let (r, g, b) = m.rgb;
        println!(
            "  [{}]  \x1b[38;2;{r};{g};{b};1m{:<10}\x1b[0m  {:<11}  {:<13}  {:<16}  {}",
            m.key, m.id, m.role_title, m.zone, m.callsign, m.anim_style
        );
    }
}

pub fn animate_cast_cli(role: &str, frames: usize) -> i32 {
    let m = resolve_cast(role).unwrap_or(&CAST_ROSTER[0]);
    let (r, g, b) = m.rgb;
    println!("  [OK] Animating 16-bit sprite for {} ({}) — {} frames ({})", m.role_title, m.callsign, frames, m.anim_style);
    for f in 0..frames.max(1) {
        println!("  -- Frame {:02} --", f + 1);
        for line in sprite_lines(m.id, f) {
            println!("    \x1b[38;2;{r};{g};{b};1m{line}\x1b[0m");
        }
    }
    0
}


pub fn trigger_banner(kind: &str, sub: Option<&str>) -> i32 {
    let (id, sfx, label) = match kind.to_ascii_lowercase().as_str() {
        "ready" | "boot" | "login" | "unlock" => ("ready", "startup", "R E A D Y"),
        "warn" | "warning" | "critical" | "alert" | "danger" => ("warning", "alert", "W A R N I N G"),
        "update" | "forge" | "complete" => ("update", "confirm", "U P D A T E   C O M P L E T E"),
        "checkpoint" | "snapshot" | "btrfs" | "saved" => ("checkpoint", "confirm", "C H E C K P O I N T   S A V E D"),
        _ => {
            eprintln!("Usage: supernotify --banner <ready|warning|update|checkpoint>");
            return 2;
        }
    };
    let ok = if let Some(s) = sub.filter(|x| !x.is_empty()) {
        qs_call("notifications", &["bannerSub", id, s]) || qs_call("notifications", &["banner", id])
    } else {
        qs_call("notifications", &["banner", id])
    };
    if !ok {
        play_sfx(sfx);
    }
    println!("  [OK] Banner triggered: {label}");
    0
}

pub fn trigger_cast(role: &str, custom_title: Option<&str>, custom_body: Option<&str>) -> i32 {
    let r = role.to_ascii_lowercase();
    if r == "all" || r == "test" || r == "showcase" {
        let _ = qs_call("notifications", &["cast", "all"]);
        println!("  [OK] Cast comms triggered: Full 10-Character Workstation Cast Showcase");
        return 0;
    }
    let Some(m) = resolve_cast(&r) else {
        eprintln!("Usage: supernotify --cast <ai|security|builder|engineer|app|navigator|medic|archivist|commander|synth|all>");
        return 2;
    };
    if let Some(title) = custom_title {
        let body = custom_body.unwrap_or(m.sample_body);
        let _ = Command::new("notify-send").args(["-u", m.urgency, "-a", m.callsign, title, body]).status();
        println!("  [OK] Cast comms transmitted [{}]: {title}", m.callsign);
        return 0;
    }
    if !qs_call("notifications", &["cast", m.id]) {
        let _ = Command::new("notify-send").args(["-u", m.urgency, "-a", m.callsign, m.sample_title, m.sample_body]).status();
    }
    println!("  [OK] Cast comms triggered: {}", m.desc);
    0
}
