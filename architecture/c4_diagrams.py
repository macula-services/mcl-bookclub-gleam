"""Generate mcl-bookclub-gleam's two C4 diagrams into assets/.

Run:  python3 architecture/c4_diagrams.py

  c4-context.svg     Level 1: what the service talks to
  c4-components.svg  Level 2: what it is made of

Drawn from the code, never from a template: the contract in service.gleam, the
boot order in app.gleam and root_supervisor.gleam, the facade tree in
facade_supervisor.gleam, the handler in get_bookclub_by_id.gleam, the admin
routes in admin.gleam, the three division supervisors, the bindings under
internal/, the dependencies in gleam.toml, the ports and volumes in the
Containerfile. When one of those changes, the diagram changes in the same commit.

Colours are plain classes with a prefers-color-scheme: dark block, no CSS custom
properties (rsvg-convert renders those black), so the SVGs render the same on
GitHub, in IDE previews and through rsvg-convert. After a change, render each
(rsvg-convert -w 1400 assets/c4-context.svg -o /tmp/c.png) and look at it; keep
architecture/README.md's tables in step.
"""
import os
from xml.sax.saxutils import escape

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets")

SANS = '"Atkinson Hyperlegible", "Segoe UI", system-ui, -apple-system, Helvetica, Arial, sans-serif'
MONO = '"JetBrains Mono", ui-monospace, Menlo, Consolas, monospace'

# Element kinds, each (light fill, light stroke, dark fill, dark stroke).
KINDS = {
    "b-sys": ("#F5E9CC", "#A56F0A", "#3A2E13", "#E3AA3C"),   # in scope
    "b-per": ("#E3EBF2", "#3B5B7A", "#1D2A36", "#8EB4D8"),   # person
    "b-mac": ("#E6E4EE", "#5E5A78", "#26243A", "#A9A4C8"),   # Macula infrastructure
    "b-lib": ("#E7F0E8", "#4A7A55", "#1A241C", "#8FBE9B"),   # library
    "b-ext": ("#ECEFED", "#8A9791", "#1C2421", "#7D8B85"),   # external system
    "b-cmp": ("#FFFFFF", "#8A9791", "#171F1C", "#7D8B85"),   # component or container
}

STYLE = f"""<style>
.t-name {{ font-family: {SANS}; font-size: 15px; font-weight: 700; }}
.t-desc {{ font-family: {SANS}; font-size: 12.5px; }}
.t-rel {{ font-family: {SANS}; font-size: 11.5px; paint-order: stroke; stroke-width: 4px; stroke-linejoin: round; }}
.t-code {{ font-family: {MONO}; font-size: 13px; font-weight: 600; }}
.t-type {{ font-family: {MONO}; font-size: 11.5px; }}
.t-bound {{ font-family: {MONO}; font-size: 12px; font-weight: 600; }}
.t-leg {{ font-family: {SANS}; font-size: 12px; }}
.edge {{ fill: none; stroke-width: 1.25; }}
.edge-later {{ fill: none; stroke-width: 1.25; stroke-dasharray: 5 4; }}
.bg {{ fill: #FFFFFF; }}
""" + "".join(f".{k} {{ fill: {v[0]}; stroke: {v[1]}; stroke-width: {2 if k == 'b-sys' else 1.25}; }}\n" for k, v in KINDS.items()) + """\
.b-later { fill: none; stroke: #8A9791; stroke-width: 1.25; stroke-dasharray: 5 4; }
.bound { fill: none; stroke: #B3BDB8; stroke-width: 1; }
.head { fill: #3B5B7A; }
.t-name, .t-code { fill: #16201D; }
.t-type, .t-bound, .t-leg { fill: #66736E; }
.t-desc { fill: #34413C; }
.t-rel { fill: #66736E; stroke: #FFFFFF; }
.edge, .edge-later { stroke: #8A9791; }
.arrowhead { fill: #8A9791; }
@media (prefers-color-scheme: dark) {
.bg { fill: #171F1C; }
""" + "".join(f".{k} {{ fill: {v[2]}; stroke: {v[3]}; }}\n" for k, v in KINDS.items()) + """\
.b-later { stroke: #7D8B85; }
.bound { stroke: #4A5752; }
.head { fill: #8EB4D8; }
.t-name, .t-code { fill: #E6ECE9; }
.t-type, .t-bound, .t-leg { fill: #93A09A; }
.t-desc { fill: #C3CDC8; }
.t-rel { fill: #93A09A; stroke: #171F1C; }
.edge, .edge-later { stroke: #7D8B85; }
.arrowhead { fill: #7D8B85; }
}
</style>"""

DEFS = ('<defs><marker id="a" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="7" markerHeight="7" '
        'orient="auto-start-reverse"><path class="arrowhead" d="M0 0L10 5L0 10z"/></marker></defs>')

LEGEND = [("b-sys", "In scope"), ("b-per", "Person"), ("b-mac", "Macula infrastructure"),
          ("b-lib", "Library"), ("b-ext", "External system"), ("b-cmp", "Container or component")]
BOUNDARY = ("bound", "Boundary")


class Diagram:
    def __init__(self, name, title, w, h):
        self.name, self.title, self.w, self.h, self.parts = name, title, w, h, []

    def text(self, cls, x, y, s, anchor=None, rotate=None):
        a = f' text-anchor="{anchor}"' if anchor else ""
        r = f' transform="rotate({rotate} {x} {y})"' if rotate is not None else ""
        self.parts.append(f'<text class="{cls}" x="{x}" y="{y}"{a}{r}>{escape(s)}</text>')

    def box(self, cls, x, y, w, h, name, kind, desc, person=False, code=False):
        # A box that is too small for its own words renders as text on top of the
        # next box, which no test would catch and a reader would read as the
        # diagram saying something it does not. Fail here instead.
        need = 70 + 16 * max(len(desc) - 1, 0) + 18
        if h < need:
            raise ValueError(f"{self.name}: {name} needs height {need}, has {h}")
        for line in desc:
            if 16 + 6.2 * len(line) > w - 16:
                raise ValueError(f"{self.name}: {name}: '{line}' is wider than {w - 32}px")
        self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="{w}" height="{h}" rx="10"/>')
        tx = x + 16
        if person:
            self.parts.append(f'<circle class="head" cx="{x + 26}" cy="{y + 24}" r="9"/>')
            tx = x + 44
        self.text("t-code" if code else "t-name", tx, y + 28, name)
        self.text("t-type", tx, y + 46, kind)
        for i, line in enumerate(desc):
            self.text("t-desc", x + 16, y + 70 + 16 * i, line)

    def bound(self, x, y, w, h, label):
        self.parts.append(f'<rect class="bound" x="{x}" y="{y}" width="{w}" height="{h}" rx="12"/>')
        self.text("t-bound", x + 16, y + 22, label)

    def edge(self, d, later=False):
        self.parts.append(f'<path class="{"edge-later" if later else "edge"}" d="{d}" marker-end="url(#a)"/>')

    def legend(self, y, boundary=True):
        x = 24
        for cls, label in LEGEND + ([BOUNDARY] if boundary else []):
            self.parts.append(f'<rect class="{cls}" x="{x}" y="{y}" width="22" height="14" rx="3"/>')
            self.text("t-leg", x + 30, y + 12, label)
            x += 34 + 6.6 * len(label)

    def write(self):
        svg = [f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {self.w} {self.h}" role="img" '
               f'aria-label="{escape(self.title)}">', f"<title>{escape(self.title)}</title>", STYLE, DEFS,
               f'<rect class="bg" x="0" y="0" width="{self.w}" height="{self.h}"/>'] + self.parts + ["</svg>", ""]
        with open(os.path.join(OUT, self.name), "w") as f:
            f.write("\n".join(svg))


def context():
    d = Diagram("c4-context.svg", "mcl-bookclub-gleam system context", 1000, 680)
    d.box("b-per", 40, 30, 270, 120, "Club operator", "[Person]",
          ["Runs the club from the LAN", "admin UI: initiates, registers",
           "members, procures, plans parties"], person=True)
    d.box("b-per", 690, 30, 270, 120, "Mesh consumer", "[Person, app or service]",
          ["Calls mcl-bookclub/", "get_bookclub_by_id and subscribes",
           "to the fact topics"], person=True)
    d.box("b-sys", 365, 186, 270, 152, "mcl-bookclub-gleam", "[mcl_om mesh service, own box]",
          ["One Gleam OTP app, four", "departments. One procedure of its own",
           "on the mesh, the LAN admin UI", "on 8490, and /health on 8455"])
    d.box("b-ext", 40, 400, 270, 120, "Host disk", "[External system]",
          ["The club store and sqlite read", "model under /var/lib, the node",
           "key under /etc/mcl/secrets"])
    d.box("b-mac", 365, 400, 270, 120, "macula-realm", "[Macula infrastructure]",
          ["Endorses the node's identity key", "and grants the scope mcl-bookclub",
           "for its action and its fact topics"])
    d.box("b-mac", 690, 400, 270, 120, "Macula stations, mesh DHT", "[Macula infrastructure]",
          ["Pinned stations are the mesh entry", "(QUIC); the DHT holds the",
           "adverts, and carries the facts"])
    d.edge("M175 150V176H400V186")
    d.text("t-rel", 183, 170, "commands on 8490, and reads")
    d.edge("M825 150V176H620V186")
    d.text("t-rel", 690, 170, "calls get_bookclub_by_id")
    d.edge("M420 338V400"); d.text("t-rel", 428, 370, "boot claim, scope")
    d.edge("M620 338V368H825V400"); d.text("t-rel", 632, 360, "advertises, publishes 3 facts")
    d.edge("M365 300H340V460H310")
    d.text("t-rel", 330, 340, "keeps the log and the read model", anchor="middle", rotate=-90)
    d.text(
        "t-desc",
        40,
        566,
        "Same org, topics and procedure names as the Erlang and Phoenix bookclubs: a peer cannot tell the",
    )
    d.text(
        "t-desc",
        40,
        584,
        "three apart. Only the three facts leave; the mesh never sees a command, and every query is answered locally.",
    )
    d.legend(630, boundary=False)
    d.write()


def components():
    d = Diagram("c4-components.svg", "mcl-bookclub-gleam components", 1340, 1360)
    d.bound(16, 40, 1292, 940, "mcl-bookclub-gleam [Container] - one Gleam OTP app, four departments")
    # Row 1: the boot order, and the contract mcl_om calls.
    d.box("b-cmp", 32, 76, 340, 136, "root_supervisor", "[gleam_otp static supervisor]",
          ["Starts the three division supervisors,",
           "before mcl_om:boot/1, so the catch-up",
           "replay finds every projection registered"], code=True)
    d.box("b-cmp", 492, 76, 340, 136, "app", "[OTP application start callback]",
          ["root_supervisor, then internal/store:open,",
           "then mcl_om:boot/1 with the service module;",
           "a store that cannot open stops the boot"], code=True)
    d.box("b-sys", 952, 76, 340, 136, "service", "[the mcl_om_service contract]",
          ["The six mcl_om_service callbacks, plus",
           "mcl-om's open info and get_limits; health",
           "pings both store actors via the FFI"], code=True)
    # Row 2: the store, the facade tree, the mesh handler.
    d.box("b-cmp", 32, 272, 340, 136, "internal/store", "[the FFI's open_store/2]",
          ["start_store, wait until reckon_db lists it,",
           "then the per-store evoq subscription; the",
           "id and the charlist dir come from data_dir"], code=True)
    d.box("b-cmp", 492, 272, 340, 136, "facade_supervisor", "[gleam_otp static supervisor]",
          ["The admin listener and the three",
           "emit_*_to_mesh handlers; started by",
           "service:start/1, after boot's replay"], code=True)
    d.box("b-sys", 952, 272, 340, 136, "get_bookclub_by_id", "[macula_response handler]",
          ["handle_request/2 reads club_id with",
           "mcl_om_wire:field/2, answers from the QRY",
           "desk; text back as CBOR text, bools 1/0"], code=True)
    # Row 3: the three departments.
    d.box("b-cmp", 32, 468, 340, 180, "project_bookclub", "[PRJ division]",
          ["bookclub_read_model_store: a gleam_otp",
           "actor owning one esqlite connection and",
           "the DDL; eight projections, one",
           "evoq_event_handler each, INSERT OR",
           "REPLACE per event, replay_policy deliver"], code=True)
    d.box("b-cmp", 492, 468, 340, 180, "host_bookclub", "[CMD division]",
          ["Nine desks and four aggregates; commands",
           "dispatch through evoq_command_router to",
           "the reckon-db store, and the",
           "on_member_registered_v1_maybe_plan_party",
           "policy is the one handler child here"], code=True)
    d.box("b-cmp", 952, 468, 340, 180, "query_bookclub", "[QRY division]",
          ["bookclub_query_store: a gleam_otp actor,",
           "read-only by API, q/2 only, so a desk",
           "cannot write. Five pure desks answer",
           "with typed records, converting the",
           "Dynamic cells q/2 returns to fields"], code=True)
    # The Erlang edge, then the libraries.
    d.box("b-cmp", 32, 680, 1260, 104, "mcl_bookclub_gleam_ffi.erl", "[Erlang, the edge Gleam cannot type]",
          ["used by internal/store, the store actors, the emitters and the admin: evoq's {ok, Version, Events},",
           "mcl_om's {ok, Pool, Realm}, esqlite's list-or-error, and the safe_ping that cannot crash its caller"], code=True)
    d.text("t-desc", 32, 818, "The libraries every department links:")
    d.box("b-lib", 32, 832, 300, 136, "gleam_otp + gleam_erlang", "[>= 1.0.0, < 2.0.0]",
          ["actors for the two stores,", "static supervisors, and the",
           "subjects replies ride"], code=True)
    d.box("b-lib", 352, 832, 300, 136, "mcl_om + macula", "[mcl_om >= 0.37.0, < 1.0.0]",
          ["boot/1: node key, realm join;",
           "QUIC pool, health, adverts;",
           "publish on a fact topic"], code=True)
    d.box("b-lib", 672, 832, 300, 136, "reckon_db + evoq", "[~> 5.4, >= 1.26.1]",
          ["the event log and the CQRS", "framework, with reckon_evoq",
           ">= 2.7.2 as the adapter"], code=True)
    d.box("b-lib", 992, 832, 300, 136, "esqlite + cowboy + jsx", "[~> 0.9, 2.12.0, 3.1.0]",
          ["one sqlite file per store,", "the admin listener, and the",
           "JSON codec behind it"], code=True)
    # The wiring between the boxes.
    d.edge("M492 160H372"); d.text("t-rel", 432, 152, "starts, then boots", anchor="middle")
    d.edge("M832 200H952"); d.text("t-rel", 892, 192, "mcl_om:boot/1", anchor="middle")
    d.edge("M560 212V240H250V272"); d.text("t-rel", 300, 232, "opens it, then boot")
    d.edge("M1112 212V272"); d.text("t-rel", 1120, 246, "capabilities/0 names it")
    d.edge("M212 408V468"); d.text("t-rel", 220, 442, "delivers every event")
    d.edge("M632 408V468"); d.text("t-rel", 640, 442, "admin writes, emitters publish")
    d.edge("M1112 408V468"); d.text("t-rel", 1120, 442, "answers from the desk")
    # The host's environment.
    d.box("b-ext", 32, 1008, 600, 104, "MCL_DATA_DIR", "[environment, /var/lib/mcl-bookclub-gleam]",
          ["read by internal/data_dir for both stores; the club",
           "store and the sqlite read model live under it"], code=True)
    d.box("b-ext", 652, 1008, 640, 104, "MCL_ADMIN_PORT", "[environment, 8490 for now]",
          ["the cowboy listener binds every interface: the admin",
           "UI is the box's LAN tool. MCL_HEALTH_PORT is 8455"], code=True)
    d.box("b-ext", 32, 1136, 1260, 104, "MCL_REALM, MCL_REALM_KEY, MCL_IDENTITY_KEY_PATH",
          "[environment, config/sys.config.src, read at boot]",
          ["the realm and its trust anchor, and the node key's path on the secrets volume;",
           "the key must survive restarts, because a peer pins this node's id"], code=True)
    d.text("t-desc", 32, 1274, "config/sys.config.src fixes the org mcl-bookclub, the PQ crypto profile pq_hybrid, and the evoq block naming")
    d.text("t-desc", 32, 1292, "mcl_bookclub_store; without that block the subscription crashes on {not_configured, event_store_adapter}.")
    d.text("t-desc", 32, 1310, "PRJ writes the one sqlite file and QRY reads it; a schema-contract test pins the columns one selects to the other's DDL.")
    d.legend(1336)
    d.write()


if __name__ == "__main__":
    for make in (context, components):
        make()
