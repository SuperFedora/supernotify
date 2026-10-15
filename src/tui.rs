// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::cast::{CAST_ROSTER, sprite_lines, sync_cast_assets, trigger_banner, trigger_cast};
use crate::state::{NotifyEnv, load_notifs, qs_call, save_notifs};
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
use std::io;
use std::time::Duration;

pub fn run_tui(env: &NotifyEnv) -> i32 {
    if enable_raw_mode().is_err() {
        return 1;
    }
    let mut stdout = io::stdout();
    let _ = execute!(stdout, EnterAlternateScreen);
    let Ok(mut term) = Terminal::new(CrosstermBackend::new(stdout)) else {
        let _ = disable_raw_mode();
        return 1;
    };
    let _ = sync_cast_assets(env);
    let mut st = load_notifs(env);
    let mut sel: usize = 0;
    let mut frame: usize = 0;
    let mut msg = String::from("SuperNotify 16-Bit Cast Studio & Animated Comms Deck Ready");

    loop {
        let _ = term.draw(|f| {
            let (pri, sec) = (env.pri(), env.sec());
            let rows = Layout::default()
                .direction(Direction::Vertical)
                .constraints([Constraint::Length(3), Constraint::Length(13), Constraint::Min(6), Constraint::Length(3)])
                .split(f.area());

            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(" [::] SUPERNOTIFY v0.1.0 ", Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD)),
                Span::raw(format!(
                    "  Cast: 10 Specialists  |  Animations: {} [a]  |  DND: {} [d]  |  Unread: {} ",
                    if st.animations { "ON (60fps/SVG)" } else { "PAUSED" },
                    if st.dnd { "ON" } else { "OFF" },
                    st.history.len()
                )),
            ]))
            .block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let mid = Layout::default()
                .direction(Direction::Horizontal)
                .constraints([Constraint::Percentage(54), Constraint::Percentage(46)])
                .split(rows[1]);

            let roster_items: Vec<ListItem> = CAST_ROSTER
                .iter()
                .enumerate()
                .map(|(i, m)| {
                    let c = Color::Rgb(m.rgb.0, m.rgb.1, m.rgb.2);
                    let pfx = if i == sel { "▸ " } else { "  " };
                    let st_mod = if i == sel { Style::default().fg(c).add_modifier(Modifier::BOLD) } else { Style::default().fg(Color::White) };
                    ListItem::new(Line::from(vec![
                        Span::styled(format!("{pfx}[{}] {:<10} ", m.key, m.id.to_uppercase()), st_mod),
                        Span::styled(format!("{:<12} ", m.role_title), Style::default().fg(c)),
                        Span::raw(format!("({})", m.zone)),
                    ]))
                })
                .collect();
            f.render_widget(
                List::new(roster_items).block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(sec))
                        .title(" 16-BIT ANIMATED CAST ROSTER (Up/Down/Enter or 1-9,0) "),
                ),
                mid[0],
            );

            let active = &CAST_ROSTER[sel];
            let ac = Color::Rgb(active.rgb.0, active.rgb.1, active.rgb.2);
            let sp = sprite_lines(active.id, if st.animations { frame } else { 0 });
            let preview_lines = vec![
                Line::from(vec![
                    Span::styled(format!("  {}  ", sp[0]), Style::default().fg(ac).add_modifier(Modifier::BOLD)),
                    Span::styled(format!("[ {} // {} ]", active.role_title, active.callsign), Style::default().fg(ac).add_modifier(Modifier::BOLD)),
                ]),
                Line::from(vec![
                    Span::styled(format!("  {}  ", sp[1]), Style::default().fg(ac)),
                    Span::raw(format!("Zone : {}  |  Urgency: {}", active.zone, active.urgency.to_uppercase())),
                ]),
                Line::from(vec![
                    Span::styled(format!("  {}  ", sp[2]), Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
                    Span::raw(format!("Anim : {}", active.anim_style)),
                ]),
                Line::from(vec![
                    Span::styled(format!("  {}  ", sp[3]), Style::default().fg(ac)),
                    Span::styled(active.sample_title, Style::default().fg(Color::White).add_modifier(Modifier::BOLD)),
                ]),
                Line::from(vec![
                    Span::styled(format!("  {}  ", sp[4]), Style::default().fg(ac).add_modifier(Modifier::BOLD)),
                    Span::raw(active.sample_body),
                ]),
            ];
            f.render_widget(
                Paragraph::new(preview_lines).block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(ac))
                        .title(format!(" LIVE 16-BIT SPRITE & COMMS PREVIEW [FRAME {:02}] ", (frame % 4) + 1)),
                ),
                mid[1],
            );

            let hist_items: Vec<ListItem> = if st.history.is_empty() {
                vec![ListItem::new("  [--] No unread notifications in history. Press [Enter] or [1-9,0] to test Cast Comms.")]
            } else {
                st.history
                    .iter()
                    .enumerate()
                    .map(|(i, v)| {
                        let s = v.get("summary").and_then(|x| x.as_str()).unwrap_or("Notification");
                        let b = v.get("body").and_then(|x| x.as_str()).unwrap_or("");
                        let role = v.get("roleTitle").or_else(|| v.get("role")).and_then(|x| x.as_str()).unwrap_or("SYS ENG");
                        ListItem::new(format!("  [{:02}] [{role}] {s} — {b}", i + 1))
                    })
                    .collect()
            };
            f.render_widget(
                List::new(hist_items).block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(sec))
                        .title(" NOTIFICATION HISTORY & MULTI-ZONE RELAY QUEUE "),
                ),
                rows[2],
            );

            let ftr = Paragraph::new(Line::from(vec![
                Span::styled(" KEYS ", Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD)),
                Span::raw(" [Enter] Fire Cast  [s] Showcase All  [a] Anim  [d] DND  [c] Clear  [r/w/u/p] Banners  [q] Quit | "),
                Span::styled(&msg, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            ]))
            .block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(ftr, rows[3]);
        });

        if event::poll(Duration::from_millis(220)).unwrap_or(false)
            && let Ok(Event::Key(k)) = event::read()
            && k.kind == KeyEventKind::Press
        {
            match k.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Up | KeyCode::Char('k') => sel = (sel + CAST_ROSTER.len() - 1) % CAST_ROSTER.len(),
                KeyCode::Down | KeyCode::Char('j') => sel = (sel + 1) % CAST_ROSTER.len(),
                KeyCode::Enter | KeyCode::Char(' ') => {
                    let m = &CAST_ROSTER[sel];
                    let _ = trigger_cast(m.id, None, None);
                    msg = format!("Fired Cast Comms: {} ({})", m.role_title, m.callsign);
                }
                KeyCode::Char('s') => {
                    let _ = trigger_cast("all", None, None);
                    msg = "Triggered Full 10-Character Cast Showcase".into();
                }
                KeyCode::Char('a') => {
                    st.animations = !st.animations;
                    save_notifs(env, &st);
                    msg = format!("Sprite Animations: {}", if st.animations { "ON" } else { "PAUSED" });
                }
                KeyCode::Char('d') => {
                    st.dnd = !st.dnd;
                    save_notifs(env, &st);
                    let _ = qs_call("notifications", &["setDnd", if st.dnd { "on" } else { "off" }]);
                    msg = format!("Do Not Disturb: {}", if st.dnd { "on" } else { "off" });
                }
                KeyCode::Char('c') => {
                    st.history.clear();
                    save_notifs(env, &st);
                    let _ = qs_call("notifications", &["dismissAll"]);
                    msg = "Cleared all notifications".into();
                }
                KeyCode::Char('r') => { let _ = trigger_banner("ready", None); msg = "Banner: READY".into(); }
                KeyCode::Char('w') => { let _ = trigger_banner("warning", None); msg = "Banner: WARNING".into(); }
                KeyCode::Char('u') => { let _ = trigger_banner("update", None); msg = "Banner: UPDATE COMPLETE".into(); }
                KeyCode::Char('p') => { let _ = trigger_banner("checkpoint", None); msg = "Banner: CHECKPOINT SAVED".into(); }
                KeyCode::Char(ch @ ('0'..='9')) => {
                    if let Some(idx) = CAST_ROSTER.iter().position(|m| m.key == ch) {
                        sel = idx;
                        let m = &CAST_ROSTER[sel];
                        let _ = trigger_cast(m.id, None, None);
                        msg = format!("Cast Comms: {} ({})", m.role_title, m.callsign);
                    }
                }
                _ => {}
            }
        }
        frame = frame.wrapping_add(1);
    }

    let _ = disable_raw_mode();
    let _ = execute!(term.backend_mut(), LeaveAlternateScreen);
    let _ = term.show_cursor();
    0
}
