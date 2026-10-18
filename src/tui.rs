// Copyright 2026 SuperFedora Contributors
// SPDX-License-Identifier: Apache-2.0

use crate::cast::{trigger_cast, trigger_warning};
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
    let mut st = load_notifs(env);
    let mut msg = String::from("Ready");

    loop {
        let _ = term.draw(|f| {
            let (pri, sec) = (env.pri(), env.sec());
            let rows = Layout::default()
                .direction(Direction::Vertical)
                .constraints([Constraint::Length(3), Constraint::Min(8), Constraint::Length(3)])
                .split(f.area());

            let hdr = Paragraph::new(Line::from(vec![
                Span::styled(
                    " SUPERNOTIFY ",
                    Style::default().fg(Color::Black).bg(pri).add_modifier(Modifier::BOLD),
                ),
                Span::raw(format!(
                    "  Do Not Disturb: {}  |  Unread: {} ",
                    if st.dnd { "ON" } else { "OFF" },
                    st.history.len()
                )),
            ]))
            .block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(hdr, rows[0]);

            let hist_items: Vec<ListItem> = if st.history.is_empty() {
                vec![ListItem::new("  No unread notifications.")]
            } else {
                st.history
                    .iter()
                    .enumerate()
                    .map(|(i, v)| {
                        let t = v.get("time").and_then(|x| x.as_str()).unwrap_or("--:--");
                        let s = v.get("summary").and_then(|x| x.as_str()).unwrap_or("Notification");
                        let b = v.get("body").and_then(|x| x.as_str()).unwrap_or("");
                        if b.is_empty() {
                            ListItem::new(format!("  [{:02}] {t}  {s}", i + 1))
                        } else {
                            ListItem::new(format!("  [{:02}] {t}  {s} — {b}", i + 1))
                        }
                    })
                    .collect()
            };
            f.render_widget(
                List::new(hist_items).block(
                    Block::default()
                        .borders(Borders::ALL)
                        .border_style(Style::default().fg(sec))
                        .title(" NOTIFICATIONS "),
                ),
                rows[1],
            );

            let ftr = Paragraph::new(Line::from(vec![
                Span::styled(
                    " KEYS ",
                    Style::default().fg(Color::Black).bg(sec).add_modifier(Modifier::BOLD),
                ),
                Span::raw(" [Enter] Test Notification  [w] WARNING  [d] Toggle DND  [c] Clear All  [q] Quit  |  "),
                Span::styled(&msg, Style::default().fg(pri).add_modifier(Modifier::BOLD)),
            ]))
            .block(Block::default().borders(Borders::ALL).border_style(Style::default().fg(pri)));
            f.render_widget(ftr, rows[2]);
        });

        if event::poll(Duration::from_millis(220)).unwrap_or(false)
            && let Ok(Event::Key(k)) = event::read()
            && k.kind == KeyEventKind::Press
        {
            match k.code {
                KeyCode::Char('q') | KeyCode::Esc => break,
                KeyCode::Enter | KeyCode::Char(' ') | KeyCode::Char('t') => {
                    let _ = trigger_cast("test", None, None);
                    st = load_notifs(env);
                    msg = "Sent test notification".into();
                }
                KeyCode::Char('w') => {
                    let _ = trigger_warning(None);
                    msg = "Triggered WARNING".into();
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
                _ => {}
            }
        }
    }

    let _ = disable_raw_mode();
    let _ = execute!(term.backend_mut(), LeaveAlternateScreen);
    let _ = term.show_cursor();
    0
}
