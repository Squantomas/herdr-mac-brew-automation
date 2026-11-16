// launchd automations from ~/.config/automations/automations.json: status, show, run, pause, edit.

import { View, div, svg } from "gpui-kit";
import { v_flex, h_flex } from "gpui-base";
import { exec, home, spaces, run, theme, layout, checking } from "herdr";

function find(node, id) {
  if (node?.id === id) return node;
  for (const child of node?.children ?? []) {
    const found = find(child, id);
    if (found) return found;
  }
  return null;
}
const narrow = () => (find(layout(), "sidebar")?.size?.px ?? Infinity) < 160;
const LIST = () => `${home()}/.config/automations/automations.json`;
const sh = (cmd) => exec("/bin/sh", ["-c", cmd]);

export default class Automations extends View {
  init(_props, cx) {
    this.items = [];
    this.error = null;
    this.hovered = null;
    if (checking()) return;
    cx.timer.every(60000, (cx) => this.refresh(cx));
    this.refresh(cx);
  }

  refresh(cx) {
    cx.spawn(async (cx) => {
      try {
        const r = await exec(`${home()}/bin/automations-status.sh`);
        this.items = JSON.parse(r.stdout);
        this.error = null;
      } catch (e) {
        this.error = String(e?.message ?? e);
      }
      cx.notify();
    });
  }

  // Runs a launchctl command for one automation, then reads the status again.
  act(cx, cmd) {
    cx.spawn(async (cx) => {
      try {
        await sh(cmd);
      } catch (e) {
        this.error = String(e?.message ?? e);
      }
      this.refresh(cx);
    });
  }

  show(a) {
    const space = spaces().find((s) => s.name === a.space && !s.machine);
    const tab = space?.tabs.find((t) => t.name === a.tab);
    if (space && tab) {
      run("space.select", { id: space.id });
      run("tab.select", { id: tab.id });
    } else if (a.log) {
      run("tab.new", { name: `log ${a.name}`, argv: ["less", "+G", a.log] });
    }
  }

  edit(files, name) {
    run("tab.new", { name: `edit ${name}`, argv: ["/bin/zsh", "-lc", 'exec "${EDITOR:-nvim}" "$@"', "edit", ...files] });
  }

  render(cx) {
    const t = theme();
    const collapsed = narrow();
    const color = (a) => (!a.enabled ? t.dim : a.running ? t.working ?? t.accent : a.last_exit ? t.blocked ?? t.ansi1 : t.ansi2 ?? t.done);
    const dot = (a) => div().w(8).h(8).flex_none().rounded(4).bg(color(a));

    const button = (id, icon, tip, fn) =>
      div()
        .id(id)
        .flex_none()
        .p(3)
        .rounded(4)
        .text_color(t.dim)
        .cursor_pointer()
        .hover((s) => s.bg(t.hover).text_color(t.foreground))
        .tooltip(tip)
        .on_click((_e, cx) => {
          cx.stop_propagation();
          fn(cx);
        })
        .child(svg(icon).size(13));

    // "2026-11-16 13:13:21 text" -> "16.11. 13:13"
    const last = (a) => {
      const m = /^(\d{4})-(\d\d)-(\d\d) (\d\d:\d\d)/.exec(a.last_line ?? "");
      return m ? `zuletzt ${m[3]}.${m[2]}. ${m[4]}` : "noch kein Lauf";
    };
    const row = (a) => {
      if (collapsed) {
        return h_flex().id(`au-${a.label}`).h(26).flex_none().items_center().justify_center()
          .hover((s) => s.bg(t.hover)).tooltip(`${a.name}: ${a.schedule}`).on_click(() => this.show(a)).child(dot(a));
      }
      const over = this.hovered === a.label;
      const target = `gui/$(id -u)/${a.label}`;
      return v_flex()
        .id(`au-${a.label}`)
        .px(8)
        .py(5)
        .flex_none()
        .rounded(8)
        .cursor_pointer()
        .hover((s) => s.bg(t.hover))
        .on_hover((on, cx) => {
          if (on) this.hovered = a.label;
          else if (this.hovered === a.label) this.hovered = null;
          cx.notify();
        })
        .tooltip(a.last_line || a.schedule)
        .on_click(() => this.show(a))
        .child(
          h_flex().h(20).gap(9).items_center()
            .child(dot(a))
            .child(div().flex_1().min_w(0).truncate().text_color(a.enabled ? t.foreground : t.muted).child(a.name))
            .when(over, (el) => el
              .when(a.enabled, (el) => el.child(button(`run-${a.label}`, "mods/automations/play.svg", "Jetzt ausführen", (cx) => this.act(cx, `launchctl kickstart ${target}`))))
              .child(a.enabled
                ? button(`off-${a.label}`, "mods/automations/pause.svg", "Pausieren", (cx) => this.act(cx, `launchctl bootout ${target}`))
                : button(`on-${a.label}`, "mods/automations/power.svg", "Aktivieren", (cx) => this.act(cx, `launchctl bootstrap gui/$(id -u) '${a.plist}'`)))
              .child(button(`edit-${a.label}`, "mods/workspace-chrome/square-pen.svg", "Skript und Zeitplan bearbeiten", () => this.edit([a.script, a.plist].filter(Boolean), a.name)))
              .child(button(`claude-${a.label}`, "mods/automations/sparkles.svg", "Mit Claude ansehen und bearbeiten", (cx) => this.act(cx, `"$HOME/bin/automation-edit.sh" '${a.label}'`))))
        )
        .child(div().pl(17).text_size(11).text_color(t.dim).truncate().child(`${a.enabled ? a.schedule : "pausiert"} \u00b7 ${last(a)}`));
    };

    return v_flex()
      .size_full()
      .min_h(0)
      .bg(t.chrome)
      .border_t(1)
      .border_color(t.border)
      .text_size(13)
      .when(!collapsed, (el) =>
        el.child(
          h_flex().px(16).h(41).pt(14).pb(5).flex_none().items_center().justify_between()
            .child(div().text_size(11.5).font_medium().text_color(t.dim).child("Automations"))
            .child(h_flex().gap(2)
              .child(button("au-list", "mods/workspace-chrome/square-pen.svg", "Liste bearbeiten (automations.json)", () => this.edit([LIST()], "automations")))
              .child(button("au-new", "mods/workspace-chrome/plus.svg", "Neue Automation mit Claude anlegen", (cx) => this.act(cx, `"$HOME/bin/automation-edit.sh"`)))),
        ),
      )
      .when(Boolean(this.error) && !collapsed, (el) => el.child(div().px(12).text_size(11).text_color(t.blocked ?? t.ansi1).child(this.error)))
      .child(v_flex().id("au-rows").flex_1().min_h(0).px(collapsed ? 0 : 8).overflow_y_scrollbar().children(this.items.map(row)));
  }
}
