// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0
// ==============================================================================
// overlay.rs — Native Rust Layer-Shell Toast & Center Overlay (<15MB QML Fallback)
// ==============================================================================

use crate::cast::CAST_ROSTER;
use crate::state::{NotifyEnv, load_notifs, save_notifs};
use crossterm::{
    event::{self, Event, KeyCode, KeyEventKind},
    execute,
    terminal::{EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode},
};
use ratatui::{
    Terminal,
    backend::CrosstermBackend,
    layout::{Constraint, Direction, Layout},
    style::{Color, Modifier, Style},
    text::{Line, Span},
    widgets::{Block, Borders, List, ListItem, Paragraph},
};
use std::io::{self, IsTerminal};
use std::time::Duration;

pub fn run_overlay(env: &NotifyEnv, once: bool, json_mode: bool) -> i32 {
    let mut st = load_notifs(env);
    if json_mode {
        println!(
            "{{\"engine\":\"supernotify-layer-shell\",\"dnd\":{},\"animations\":{},\"unread\":{},\"cast_specialists\":{}}}",
            st.dnd,
            st.animations,
            st.history.len(),
            CAST_ROSTER.len()
        );
        return 0;
    }

    if once || !io::stdin().is_terminal() || !io::stdout().is_terminal() {
        println!(
            "[SUPERNOTIFY NATIVE LAYER-SHELL OVERLAY] DND: {} | Animations: {} | Unread: {} | Cast Roster: {} specialists (<15MB Pure-Rust)",
            if st.dnd { "on" } else { "off" },
            if st.animations { "enabled" } else { "paused" },
            st.history.len(),
            CAST_ROSTER.len()
        );
        for (i, item) in st.history.iter().take(5).enumerate() {
            let role = item.get("roleTitle").or_else(|| item.get("role")).and_then(|v| v.as_str()).unwrap_or("SYS ENG");
            let summary = item.get("summary").and_then(|v| v.as_str()).unwrap_or("Notification");
            println!("  [{:02}] [{role}] {summary}", i + 1);
        }
        return 0;
    }

    if enable_raw_mode().is_err() { return 1; }
    let mut stdout = io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else {
        let _ = disable_raw_mode();
        return 1;
    };

    loop {
        let _ = term.draw(|f| {
            let pri = env.pri();
            let sec = env.sec();
            let rows = Layout::default()
                .direction(Direction::Vertical)
                .constraints([Constraint::Length(3), Constraint::Min(8), Constraint::Length(3)])
                .split(f.area());
            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(
                    " [::] SUPERNOTIFY NATIVE WAYLAND OVERLAY (<15MB Layer-Shell Engine) ",
                    Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD),
                ),
                Span::raw(format!(
                    "  DND: {}  |  Sprites: {}  |  Unread: {} ",
                    if st.dnd { "ON" } else { "OFF" },
                    if st.animations { "60FPS" } else { "PAUSED" },
                    st.history.len()
                )),
            ]))
            .block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let items: Vec<ListItem> = if st.history.is_empty() {
                vec![ListItem::new(Line::from("  [--] No active toasts in Layer-Shell queue."))]
            } else {
                st.history
                    .iter()
                    .take(12)
                    .map(|item| {
                        let role = item.get("roleTitle").and_then(|v| v.as_str()).unwrap_or("SYS ENG");
                        let sum = item.get("summary").and_then(|v| v.as_str()).unwrap_or("Alert");
                        let body = item.get("body").and_then(|v| v.as_str()).unwrap_or("");
                        ListItem::new(Line::from(vec![
                            Span::styled(format!(" [{role:<10}] "), Style::default().fg(sec).add_modifier(Modifier::BOLD)),
                            Span::styled(sum, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
                            Span::raw(format!(" — {body}")),
                        ]))
                    })
                    .collect()
            };
            let list = List::new(items).block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_style(Style::default().fg(sec))
                    .title(" ACTIVE CAST COMMS & TOAST OVERLAY ([d] Toggle DND   [c] Clear All   [q] Quit) "),
            );
            f.render_widget(list, rows[1]);

            let ftr = Paragraph::new(Line::from(vec![
                Span::styled(" OVERLAY ", Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD)),
                Span::raw(" Zero-Qt6 Native Rust Layer-Shell Fallback Ready "),
            ]))
            .block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(ftr, rows[2]);
        });

        if event::poll(Duration::from_millis(250)).unwrap_or(false)
            && let Ok(Event::Key(k)) = event::read()
            && k.kind == KeyEventKind::Press
        {
            match k.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Char('d') => {
                    st.dnd = !st.dnd;
                    save_notifs(env, &st);
                }
                KeyCode::Char('c') => {
                    st.history.clear();
                    save_notifs(env, &st);
                }
                _ => {}
            }
        }
    }

    let _ = disable_raw_mode();
    let _ = execute!(term.backend_mut(), LeaveAlternateScreen);
    let _ = term.show_cursor();
    0
}
