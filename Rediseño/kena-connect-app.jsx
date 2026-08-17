import { useState } from "react";
import {
  Plus, Users, QrCode, Copy, ChevronRight, ChevronLeft, Settings,
  MoreVertical, Send, Crown, LogOut, Check, ArrowLeft, Camera,
  Radar as RadarIcon, Paperclip, Trash2, Pencil, Sun, Moon, Wifi,
  X, MapPin, Image as ImageIcon, AlertCircle, ScanLine, Clock, WifiOff
} from "lucide-react";

const C = {
  bg: "#0A0908",
  card: "#15120F",
  card2: "#1B1712",
  line: "rgba(255,255,255,0.08)",
  lineStrong: "rgba(255,255,255,0.16)",
  teal: "#2BB89F",
  sky: "#3C8FC4",
  text: "#FFFFFF",
  text2: "rgba(255,255,255,0.55)",
  text3: "rgba(255,255,255,0.35)",
  green: "#3DD68C",
  red: "#FF6B6B",
};

const AVATAR_COLORS = ["#2BB89F", "#6C5CE7", "#3DD68C", "#4FA0FF", "#FF5D8F"];

const FOUND_ROOMS = [
  { name: "Familia", host: "Bruno", signal: 4 },
  { name: "Grupo camping", host: "Vale", signal: 2 },
];

const RECENT_ROOMS = [
  { name: "Familia", when: "Hace 2 días" },
];

function SignalRings({ size = 84, active = true }) {
  return (
    <div style={{ position: "relative", width: size, height: size, display: "flex", alignItems: "center", justifyContent: "center" }}>
      {active && (
        <>
          <span style={{ position: "absolute", width: size, height: size, borderRadius: "50%", border: `1px solid ${C.teal}`, opacity: 0.15 }} />
          <span style={{ position: "absolute", width: size * 0.72, height: size * 0.72, borderRadius: "50%", border: `1px solid ${C.teal}`, opacity: 0.3 }} />
          <span style={{ position: "absolute", width: size * 0.46, height: size * 0.46, borderRadius: "50%", border: `1px solid ${C.teal}`, opacity: 0.55 }} />
        </>
      )}
      <div style={{
        width: size * 0.32, height: size * 0.32, borderRadius: "50%",
        background: `linear-gradient(135deg, ${C.teal}, ${C.sky})`,
        display: "flex", alignItems: "center", justifyContent: "center",
        boxShadow: `0 0 ${size * 0.25}px rgba(43,184,159,0.22)`,
      }}>
        <Wifi size={size * 0.14} color="#fff" strokeWidth={2.4} />
      </div>
    </div>
  );
}

function SignalBar({ strength = 3, label }) {
  const bars = [4, 7, 10, 13];
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
      <div style={{ display: "flex", alignItems: "flex-end", gap: 2, height: 13 }}>
        {bars.map((h, i) => (
          <span key={i} style={{
            width: 3, height: h, borderRadius: 1,
            background: i < strength ? C.teal : "rgba(255,255,255,0.15)",
          }} />
        ))}
      </div>
      {label && <span style={{ fontSize: 11, color: C.text2, fontWeight: 600 }}>{label}</span>}
    </div>
  );
}

function TopBar({ title, subtitle, onBack, right }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "18px 20px 14px", borderBottom: `1px solid ${C.line}` }}>
      {onBack && (
        <button onClick={onBack} aria-label="Volver" style={{ background: "none", border: "none", color: C.text, padding: 4, display: "flex" }}>
          <ArrowLeft size={20} />
        </button>
      )}
      <div style={{ flex: 1, minWidth: 0 }}>
        <div style={{ fontSize: 16, fontWeight: 700, color: C.text, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{title}</div>
        {subtitle && <div style={{ fontSize: 11.5, color: C.text2, marginTop: 2 }}>{subtitle}</div>}
      </div>
      {right}
    </div>
  );
}

function Field({ label, value, onChange, placeholder, error, right }) {
  return (
    <div style={{ marginBottom: error ? 6 : 16 }}>
      <div style={{ fontSize: 11, fontWeight: 700, color: C.text2, textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: 7 }}>{label}</div>
      <div style={{ position: "relative", display: "flex", alignItems: "center" }}>
        <input
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          style={{
            width: "100%", background: C.card, border: `1px solid ${error ? C.red : C.line}`, borderRadius: 12,
            padding: right ? "13px 44px 13px 14px" : "13px 14px", fontSize: 14.5, fontWeight: 600, color: C.text, outline: "none",
          }}
        />
        {right && <div style={{ position: "absolute", right: 10 }}>{right}</div>}
      </div>
      {error && <div style={{ fontSize: 11, color: C.red, marginTop: 6, marginBottom: 10, display: "flex", alignItems: "center", gap: 5 }}><AlertCircle size={12} />{error}</div>}
    </div>
  );
}

function PrimaryButton({ children, onClick, disabled, style: extra }) {
  return (
    <button
      onClick={onClick}
      disabled={disabled}
      style={{
        width: "100%", borderRadius: 16, padding: "15px",
        fontSize: 14.5, fontWeight: 700, color: "#fff", cursor: disabled ? "not-allowed" : "pointer",
        background: disabled
          ? "rgba(255,255,255,0.06)"
          : `linear-gradient(135deg, rgba(43,184,159,0.32), rgba(60,143,196,0.32))`,
        backdropFilter: disabled ? "none" : "blur(18px) saturate(180%)",
        WebkitBackdropFilter: disabled ? "none" : "blur(18px) saturate(180%)",
        border: disabled ? "1px solid rgba(255,255,255,0.08)" : "1px solid rgba(255,255,255,0.22)",
        borderTopColor: disabled ? "rgba(255,255,255,0.08)" : "rgba(255,255,255,0.4)",
        boxShadow: disabled
          ? "none"
          : "0 6px 18px rgba(43,184,159,0.16), inset 0 1px 0 rgba(255,255,255,0.28), inset 0 -10px 16px -12px rgba(0,0,0,0.2)",
        opacity: disabled ? 0.5 : 1,
        ...extra,
      }}
    >
      {children}
    </button>
  );
}

function GhostButton({ children, onClick, danger }) {
  return (
    <button
      onClick={onClick}
      style={{
        width: "100%", borderRadius: 14,
        padding: "13px", fontSize: 13.5, fontWeight: 600, color: danger ? C.red : C.text,
        display: "flex", alignItems: "center", justifyContent: "center", gap: 8, cursor: "pointer",
        background: "rgba(255,255,255,0.06)",
        backdropFilter: "blur(14px) saturate(160%)",
        WebkitBackdropFilter: "blur(14px) saturate(160%)",
        border: "1px solid rgba(255,255,255,0.14)",
        borderTopColor: "rgba(255,255,255,0.24)",
        boxShadow: "inset 0 1px 0 rgba(255,255,255,0.12)",
      }}
    >
      {children}
    </button>
  );
}

function FakeQR() {
  return (
    <div style={{ width: 148, height: 148, background: "#fff", borderRadius: 16, margin: "0 auto", padding: 14 }}>
      <svg viewBox="0 0 100 100" width="100%" height="100%">
        <rect width="100" height="100" fill="#fff" />
        <g fill={C.bg}>
          <rect x="8" y="8" width="24" height="24" /><rect x="14" y="14" width="12" height="12" fill="#fff" />
          <rect x="68" y="8" width="24" height="24" /><rect x="74" y="14" width="12" height="12" fill="#fff" />
          <rect x="8" y="68" width="24" height="24" /><rect x="14" y="74" width="12" height="12" fill="#fff" />
          <rect x="40" y="10" width="6" height="6" /><rect x="52" y="16" width="6" height="6" />
          <rect x="40" y="40" width="6" height="6" /><rect x="52" y="46" width="6" height="6" />
          <rect x="66" y="40" width="6" height="6" /><rect x="80" y="52" width="6" height="6" />
          <rect x="40" y="66" width="6" height="6" /><rect x="52" y="80" width="6" height="6" />
          <rect x="66" y="66" width="6" height="6" />
        </g>
      </svg>
    </div>
  );
}

function Avatar({ color, initial, size = 34 }) {
  return (
    <div style={{
      width: size, height: size, borderRadius: size * 0.32, flexShrink: 0,
      background: color, display: "flex", alignItems: "center", justifyContent: "center",
      fontSize: size * 0.4, fontWeight: 700, color: "#fff",
    }}>
      {initial}
    </div>
  );
}

function Overlay({ children, onClose }) {
  return (
    <div style={{
      position: "absolute", inset: 0, background: "rgba(0,0,0,0.55)",
      display: "flex", alignItems: "flex-end", zIndex: 20, borderRadius: 34,
    }} onClick={onClose}>
      <div onClick={(e) => e.stopPropagation()} style={{
        width: "100%", background: C.card2, borderTopLeftRadius: 22, borderTopRightRadius: 22,
        padding: "18px 20px 24px", border: `1px solid ${C.lineStrong}`, borderBottom: "none",
      }}>
        {children}
      </div>
    </div>
  );
}

function CenterModal({ children }) {
  return (
    <div style={{
      position: "absolute", inset: 0, background: "rgba(0,0,0,0.6)",
      display: "flex", alignItems: "center", justifyContent: "center", zIndex: 20,
      borderRadius: 34, padding: 24,
    }}>
      <div style={{ width: "100%", background: C.card2, border: `1px solid ${C.lineStrong}`, borderRadius: 18, padding: 20 }}>
        {children}
      </div>
    </div>
  );
}

const ONBOARDING = [
  { title: "Chateá sin Internet", body: "Kena convierte los dispositivos que tenés cerca en su propia red temporal. Sin datos, sin wifi público, sin señal de celular." },
  { title: "Creá una red con tu grupo", body: "Armá una sala, compartí un código o un QR, y en segundos tenés un chat en vivo funcionando sobre la red local." },
  { title: "Solo funciona de cerca", body: "Los mensajes van y vienen mientras estén conectados a la misma red local. Si alguien se aleja, se reconecta solo al volver a estar cerca." },
];

export default function App() {
  const [stack, setStack] = useState(["onboarding"]);
  const [obStep, setObStep] = useState(0);
  const [profile, setProfile] = useState({ name: "Bruno", color: AVATAR_COLORS[0] });
  const [roomName, setRoomName] = useState("");
  const [joinCode, setJoinCode] = useState("");
  const [joinError, setJoinError] = useState("");
  const [scanning, setScanning] = useState(false);
  const [showAttach, setShowAttach] = useState(false);
  const [confirmAction, setConfirmAction] = useState(null);
  const [messages, setMessages] = useState([
    { id: 1, from: "in", text: "¿Ya están conectados a la sala?", time: "16:40" },
    { id: 2, from: "out", text: "Sí, les leo bien desde acá", time: "16:41" },
    { id: 3, from: "system", text: "Se perdió la conexión con Solchi" },
    { id: 4, from: "in", text: "Perdón, me alejé hasta el arroyo y perdí señal", time: "16:43" },
    { id: 5, from: "system", text: "Solchi volvió a conectarse" },
    { id: 6, from: "out", text: "Tranquilo, quedate cerca de la carpa y no se corta", time: "16:44" },
  ]);
  const [draft, setDraft] = useState("");

  const screen = stack[stack.length - 1];
  const go = (s) => setStack((st) => [...st, s]);
  const back = () => setStack((st) => (st.length > 1 ? st.slice(0, -1) : st));
  const resetTo = (s) => setStack([s]);

  const sendMessage = () => {
    if (!draft.trim()) return;
    setMessages((m) => [...m, { id: Date.now(), from: "out", text: draft.trim(), time: "ahora" }]);
    setDraft("");
  };

  const tryConnect = () => {
    if (!/^KENA-/i.test(joinCode.trim())) {
      setJoinError("No encontramos una sala con ese código. Revisá que empiece con KENA-.");
      return;
    }
    setJoinError("");
    go("sala");
  };

  const simulateScan = () => {
    setScanning(false);
    setJoinCode("KENA-HDVZ");
    setJoinError("");
    go("sala");
  };

  return (
    <div style={{ width: "100%", display: "flex", justifyContent: "center", padding: "8px 0" }}>
      <div style={{
        width: 320, height: 660, background: "#000", borderRadius: 42, padding: 9,
        boxShadow: "0 30px 70px -20px rgba(0,0,0,0.6)",
      }}>
        <div style={{
          width: "100%", height: "100%", borderRadius: 34, overflow: "hidden",
          background: `radial-gradient(circle at 25% 0%, rgba(43,184,159,0.10), transparent 45%),
                       radial-gradient(circle at 90% 85%, rgba(60,143,196,0.10), transparent 50%),
                       ${C.bg}`,
          display: "flex", flexDirection: "column", position: "relative",
          fontFamily: "Inter, system-ui, sans-serif", color: C.text,
        }}>
          <div style={{
            position: "absolute", top: 12, left: "50%", transform: "translateX(-50%)",
            width: 76, height: 18, borderRadius: 14, background: "#000", zIndex: 5,
          }} />
          <div style={{ padding: "17px 22px 2px", display: "flex", justifyContent: "space-between", fontSize: 10.5, fontWeight: 600, opacity: 0.8 }}>
            <span>9:41</span><span>100%</span>
          </div>

          {screen === "onboarding" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "28px 24px 24px" }}>
              <div style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", textAlign: "center" }}>
                <SignalRings size={100} />
                <div style={{ fontSize: 21, fontWeight: 700, marginTop: 26, marginBottom: 10 }}>{ONBOARDING[obStep].title}</div>
                <div style={{ fontSize: 13, color: C.text2, lineHeight: 1.55, maxWidth: 220 }}>{ONBOARDING[obStep].body}</div>
              </div>
              <div style={{ display: "flex", justifyContent: "center", gap: 6, marginBottom: 22 }}>
                {ONBOARDING.map((_, i) => (
                  <span key={i} style={{ width: i === obStep ? 18 : 6, height: 6, borderRadius: 3, background: i === obStep ? C.teal : "rgba(255,255,255,0.18)", transition: "all .2s" }} />
                ))}
              </div>
              <PrimaryButton onClick={() => {
                if (obStep < ONBOARDING.length - 1) setObStep(obStep + 1);
                else resetTo("home");
              }}>
                {obStep < ONBOARDING.length - 1 ? "Siguiente" : "Empezar"}
              </PrimaryButton>
              {obStep < ONBOARDING.length - 1 && (
                <button onClick={() => resetTo("home")} style={{ background: "none", border: "none", color: C.text3, fontSize: 12.5, fontWeight: 600, padding: "14px 0 0" }}>
                  Saltar
                </button>
              )}
            </div>
          )}

          {screen === "home" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column", padding: "10px 20px 22px" }}>
              <div style={{ display: "flex", justifyContent: "flex-end", marginBottom: 8 }}>
                <button onClick={() => go("perfil")} aria-label="Perfil" style={{ background: "none", border: "none" }}>
                  <Avatar color={profile.color} initial={profile.name[0]} size={30} />
                </button>
              </div>
              <div style={{ flex: 1, display: "flex", flexDirection: "column", justifyContent: "center", alignItems: "center", textAlign: "center" }}>
                <SignalRings size={72} />
                <div style={{ fontSize: 20, fontWeight: 700, marginTop: 14 }}>Kena Connect</div>
                <div style={{ fontSize: 12, color: C.text2, marginTop: 4 }}>Conectados, incluso sin Internet</div>
              </div>
              <RowCard icon={<Plus size={17} color={C.teal} strokeWidth={2.4} />} title="Crear una sala" sub="Red local para tu grupo" onClick={() => go("crear-sala")} />
              <RowCard icon={<Users size={17} color={C.teal} strokeWidth={2.4} />} title="Unirme a una sala" sub="Con código, QR o cerca tuyo" onClick={() => go("unirse-sala")} />
              {RECENT_ROOMS.length > 0 && (
                <>
                  <div style={{ fontSize: 11, fontWeight: 700, color: C.text2, textTransform: "uppercase", letterSpacing: "0.04em", margin: "10px 2px 8px" }}>Recientes</div>
                  {RECENT_ROOMS.map((r) => (
                    <button key={r.name} onClick={() => go("sala")} style={{
                      width: "100%", background: "none", border: `1px solid ${C.line}`, borderRadius: 12,
                      padding: "10px 12px", display: "flex", alignItems: "center", gap: 10, marginBottom: 8, cursor: "pointer",
                    }}>
                      <Clock size={15} color={C.text3} />
                      <div style={{ flex: 1, textAlign: "left" }}>
                        <div style={{ fontSize: 12.5, fontWeight: 600 }}>{r.name}</div>
                        <div style={{ fontSize: 10.5, color: C.text3 }}>{r.when}</div>
                      </div>
                      <ChevronRight size={14} color={C.text3} />
                    </button>
                  ))}
                </>
              )}
            </div>
          )}

          {screen === "perfil" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
              <TopBar title="Tu perfil" onBack={back} />
              <div style={{ padding: "24px 20px" }}>
                <div style={{ display: "flex", justifyContent: "center", marginBottom: 22 }}>
                  <Avatar color={profile.color} initial={profile.name[0] || "?"} size={64} />
                </div>
                <Field label="Tu nombre" value={profile.name} onChange={(v) => setProfile((p) => ({ ...p, name: v }))} placeholder="Tu nombre" />
                <div style={{ fontSize: 11, fontWeight: 700, color: C.text2, textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: 10 }}>Color</div>
                <div style={{ display: "flex", gap: 10, marginBottom: 24 }}>
                  {AVATAR_COLORS.map((c) => (
                    <button key={c} onClick={() => setProfile((p) => ({ ...p, color: c }))} aria-label={`Color ${c}`} style={{
                      width: 34, height: 34, borderRadius: "50%", background: c, border: profile.color === c ? "2px solid #fff" : "2px solid transparent", cursor: "pointer",
                    }} />
                  ))}
                </div>
                <div style={{ fontSize: 11, fontWeight: 700, color: C.text2, textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: 10 }}>Apariencia</div>
                <div style={{ display: "flex", gap: 10 }}>
                  <div style={{ flex: 1, background: C.card2, border: `1px solid ${C.lineStrong}`, borderRadius: 12, padding: 12, display: "flex", alignItems: "center", gap: 8 }}>
                    <Moon size={15} color={C.teal} /><span style={{ fontSize: 12.5, fontWeight: 600 }}>Oscuro</span>
                  </div>
                  <div style={{ flex: 1, background: C.card, border: `1px solid ${C.line}`, borderRadius: 12, padding: 12, display: "flex", alignItems: "center", gap: 8, opacity: 0.5 }}>
                    <Sun size={15} /><span style={{ fontSize: 12.5, fontWeight: 600 }}>Claro</span>
                  </div>
                </div>
              </div>
            </div>
          )}

          {screen === "crear-sala" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
              <TopBar title="Crear sala" onBack={back} />
              <div style={{ padding: "22px 20px", flex: 1, display: "flex", flexDirection: "column" }}>
                <div style={{ fontSize: 12.5, color: C.text2, lineHeight: 1.5, marginBottom: 20 }}>
                  Le vamos a poner un nombre a tu sala para que la gente cerca la reconozca fácil.
                </div>
                <Field label="Nombre de la sala" value={roomName} onChange={setRoomName} placeholder="Ej: Familia" />
                <Field label="Tu nombre" value={profile.name} onChange={(v) => setProfile((p) => ({ ...p, name: v }))} />
                <div style={{ marginTop: "auto" }}>
                  <PrimaryButton disabled={!roomName.trim()} onClick={() => go("sala-creada")}>Crear sala</PrimaryButton>
                </div>
              </div>
            </div>
          )}

          {screen === "sala-creada" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
              <TopBar title={roomName || "Familia"} onBack={back} />
              <div style={{ padding: "20px 20px", flex: 1, display: "flex", flexDirection: "column" }}>
                <div style={{ fontSize: 11, fontWeight: 700, color: C.text2, textAlign: "center", textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: 12 }}>Compartí este código</div>
                <FakeQR />
                <div style={{ textAlign: "center", fontSize: 19, fontWeight: 800, color: C.teal, letterSpacing: "0.06em", margin: "14px 0 2px" }}>KENA-HDVZ</div>
                <button style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 6, background: "none", border: "none", color: C.text3, fontSize: 11.5, fontWeight: 600, margin: "0 auto 20px" }}>
                  <Copy size={12} /> Copiar código
                </button>
                <div style={{ background: C.card, border: `1px solid ${C.line}`, borderRadius: 12, padding: "11px 14px", display: "flex", alignItems: "center", gap: 10, marginBottom: 18 }}>
                  <Avatar color={profile.color} initial={profile.name[0] || "?"} size={28} />
                  <div style={{ flex: 1 }}>
                    <div style={{ fontSize: 12.5, fontWeight: 700 }}>{profile.name || "Vos"}</div>
                    <div style={{ fontSize: 10.5, color: C.text2 }}>Anfitrión</div>
                  </div>
                  <span style={{ width: 7, height: 7, borderRadius: "50%", background: C.green }} />
                </div>
                <div style={{ marginTop: "auto" }}>
                  <PrimaryButton onClick={() => go("sala")}>Entrar a la sala</PrimaryButton>
                </div>
              </div>
            </div>
          )}

          {screen === "unirse-sala" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column", position: "relative" }}>
              <TopBar title="Unirme a una sala" onBack={back} />
              <div style={{ padding: "18px 20px", flex: 1, display: "flex", flexDirection: "column", overflowY: "auto" }}>
                <Field label="Tu nombre" value={profile.name} onChange={(v) => setProfile((p) => ({ ...p, name: v }))} />
                <div style={{ fontSize: 11, fontWeight: 700, color: C.text2, textTransform: "uppercase", letterSpacing: "0.04em", marginBottom: 10 }}>Salas cerca tuyo</div>
                <div style={{ width: 116, height: 116, margin: "2px auto 12px", borderRadius: "50%", border: `1px solid ${C.line}`, position: "relative", display: "flex", alignItems: "center", justifyContent: "center" }}>
                  <span style={{ width: 9, height: 9, borderRadius: "50%", background: "#fff" }} />
                  <span style={{ position: "absolute", top: "30%", left: "62%", width: 7, height: 7, borderRadius: "50%", background: C.teal }} />
                  <span style={{ position: "absolute", top: "66%", left: "34%", width: 7, height: 7, borderRadius: "50%", background: C.teal }} />
                </div>
                {FOUND_ROOMS.map((r) => (
                  <button key={r.name} onClick={() => go("sala")} style={{
                    width: "100%", background: C.card, border: `1px solid ${C.line}`, borderRadius: 12,
                    padding: "11px 12px", display: "flex", alignItems: "center", gap: 10, marginBottom: 8, cursor: "pointer",
                  }}>
                    <div style={{ width: 30, height: 30, borderRadius: 9, background: `linear-gradient(135deg, ${C.teal}, ${C.sky})`, flexShrink: 0 }} />
                    <div style={{ flex: 1, textAlign: "left" }}>
                      <div style={{ fontSize: 12.5, fontWeight: 700 }}>{r.name}</div>
                      <div style={{ fontSize: 10.5, color: C.text3 }}>Anfitrión {r.host}</div>
                    </div>
                    <SignalBar strength={r.signal} />
                  </button>
                ))}
                <div style={{ display: "flex", alignItems: "center", gap: 10, margin: "14px 0" }}>
                  <div style={{ flex: 1, height: 1, background: C.line }} />
                  <span style={{ fontSize: 10.5, color: C.text3, fontWeight: 600 }}>O</span>
                  <div style={{ flex: 1, height: 1, background: C.line }} />
                </div>
                <Field
                  label="¿Tenés un código?"
                  value={joinCode}
                  onChange={(v) => { setJoinCode(v); setJoinError(""); }}
                  placeholder="Ej: KENA-482A"
                  error={joinError}
                  right={
                    <button onClick={() => setScanning(true)} aria-label="Escanear QR" style={{ background: "none", border: "none", color: C.teal, display: "flex" }}>
                      <QrCode size={18} />
                    </button>
                  }
                />
                <div style={{ marginTop: "auto", paddingTop: 8 }}>
                  <PrimaryButton disabled={!joinCode.trim()} onClick={tryConnect}>Conectar con código</PrimaryButton>
                </div>
              </div>

              {scanning && (
                <div style={{ position: "absolute", inset: 0, background: "#000", zIndex: 30, display: "flex", flexDirection: "column" }}>
                  <div style={{ padding: "18px 20px", display: "flex", alignItems: "center", gap: 12 }}>
                    <button onClick={() => setScanning(false)} aria-label="Cerrar" style={{ background: "none", border: "none", color: "#fff" }}><X size={20} /></button>
                    <div style={{ fontSize: 15, fontWeight: 700, color: "#fff" }}>Escanear código QR</div>
                  </div>
                  <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center", position: "relative" }}>
                    <div style={{ width: 200, height: 200, position: "relative" }}>
                      {[["0","0",1,0],["0","0",0,1],["1","0",-1,0],["1","0",0,1]].map((_, i) => null)}
                      <span style={{ position: "absolute", top: 0, left: 0, width: 28, height: 28, borderTop: `3px solid ${C.teal}`, borderLeft: `3px solid ${C.teal}`, borderRadius: "6px 0 0 0" }} />
                      <span style={{ position: "absolute", top: 0, right: 0, width: 28, height: 28, borderTop: `3px solid ${C.teal}`, borderRight: `3px solid ${C.teal}`, borderRadius: "0 6px 0 0" }} />
                      <span style={{ position: "absolute", bottom: 0, left: 0, width: 28, height: 28, borderBottom: `3px solid ${C.teal}`, borderLeft: `3px solid ${C.teal}`, borderRadius: "0 0 0 6px" }} />
                      <span style={{ position: "absolute", bottom: 0, right: 0, width: 28, height: 28, borderBottom: `3px solid ${C.teal}`, borderRight: `3px solid ${C.teal}`, borderRadius: "0 0 6px 0" }} />
                      <div style={{ position: "absolute", left: 6, right: 6, top: "50%", height: 2, background: C.teal, boxShadow: `0 0 8px ${C.teal}` }} />
                    </div>
                    <div style={{ position: "absolute", bottom: 60, textAlign: "center", color: C.text2, fontSize: 12, padding: "0 40px" }}>
                      Apuntá al código QR que te compartieron
                    </div>
                  </div>
                  <div style={{ padding: "0 20px 24px" }}>
                    <PrimaryButton onClick={simulateScan}>
                      <ScanLine size={14} style={{ verticalAlign: -2, marginRight: 6 }} />Simular detección
                    </PrimaryButton>
                  </div>
                </div>
              )}
            </div>
          )}

          {screen === "sala" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
              <TopBar
                title={roomName || "Familia"}
                subtitle={<span style={{ display: "flex", alignItems: "center", gap: 6 }}><SignalBar strength={4} /> Señal excelente</span>}
                onBack={back}
                right={
                  <div style={{ display: "flex", gap: 14 }}>
                    <button onClick={() => go("participantes")} aria-label="Participantes" style={{ background: "none", border: "none", color: C.text2 }}><Users size={18} /></button>
                    <button onClick={() => go("config-sala")} aria-label="Configuración" style={{ background: "none", border: "none", color: C.text2 }}><Settings size={18} /></button>
                  </div>
                }
              />
              <div style={{ padding: "14px 16px", flex: 1 }}>
                <ChannelRow name="General" sub={messages.filter(m=>m.from!=="system").length ? messages.filter(m=>m.from!=="system").slice(-1)[0].text : "Sin mensajes todavía"} unread={0} onClick={() => go("chat")} />
                <ChannelRow name="Solchi" sub="Chat privado" unread={2} onClick={() => go("chat")} />
              </div>
            </div>
          )}

          {screen === "chat" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column", position: "relative" }}>
              <TopBar
                title="General"
                subtitle={<span style={{ display: "flex", alignItems: "center", gap: 5, color: C.teal, fontWeight: 700 }}><span style={{ width: 5, height: 5, borderRadius: "50%", background: C.teal, display: "inline-block" }} />Sala activa</span>}
                onBack={back}
                right={<button aria-label="Más" style={{ background: "none", border: "none", color: C.text2 }}><MoreVertical size={18} /></button>}
              />
              <div style={{ flex: 1, padding: "14px 16px", display: "flex", flexDirection: "column", gap: 9, overflowY: "auto" }}>
                {messages.map((m) => (
                  m.from === "system" ? (
                    <div key={m.id} style={{ alignSelf: "center", display: "flex", alignItems: "center", gap: 6, background: "rgba(255,255,255,0.05)", borderRadius: 20, padding: "5px 12px", margin: "4px 0" }}>
                      <WifiOff size={11} color={C.text3} />
                      <span style={{ fontSize: 10.5, color: C.text3, fontWeight: 600 }}>{m.text}</span>
                    </div>
                  ) : (
                    <div key={m.id} style={{
                      maxWidth: "72%", alignSelf: m.from === "out" ? "flex-end" : "flex-start",
                      background: m.from === "out" ? `linear-gradient(135deg, ${C.teal}, ${C.sky})` : C.card,
                      border: m.from === "out" ? "none" : `1px solid ${C.line}`,
                      borderRadius: 16, borderBottomRightRadius: m.from === "out" ? 4 : 16,
                      borderBottomLeftRadius: m.from === "in" ? 4 : 16,
                      padding: "10px 13px",
                    }}>
                      <div style={{ fontSize: 13, lineHeight: 1.4 }}>{m.text}</div>
                      <div style={{ fontSize: 9, opacity: 0.55, textAlign: "right", marginTop: 3 }}>{m.time}</div>
                    </div>
                  )
                ))}
              </div>
              <div style={{ margin: "8px 14px 16px", background: C.card, border: `1px solid ${C.line}`, borderRadius: 24, padding: "6px 6px 6px 16px", display: "flex", alignItems: "center", gap: 8 }}>
                <button onClick={() => setShowAttach(true)} aria-label="Adjuntar" style={{ background: "none", border: "none", color: C.text3 }}><Paperclip size={17} /></button>
                <input
                  value={draft}
                  onChange={(e) => setDraft(e.target.value)}
                  onKeyDown={(e) => e.key === "Enter" && sendMessage()}
                  placeholder="Mensaje"
                  style={{ flex: 1, background: "none", border: "none", outline: "none", color: C.text, fontSize: 13 }}
                />
                <button onClick={sendMessage} aria-label="Enviar" style={{
                  width: 34, height: 34, borderRadius: "50%",
                  background: "linear-gradient(135deg, rgba(43,184,159,0.4), rgba(60,143,196,0.4))",
                  backdropFilter: "blur(14px) saturate(180%)", WebkitBackdropFilter: "blur(14px) saturate(180%)",
                  border: "1px solid rgba(255,255,255,0.3)", borderTopColor: "rgba(255,255,255,0.45)",
                  boxShadow: "0 4px 12px rgba(43,184,159,0.2), inset 0 1px 0 rgba(255,255,255,0.28)",
                  display: "flex", alignItems: "center", justifyContent: "center",
                }}>
                  <Send size={14} color="#fff" />
                </button>
              </div>

              {showAttach && (
                <Overlay onClose={() => setShowAttach(false)}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 16 }}>
                    <div style={{ fontSize: 14, fontWeight: 700 }}>Adjuntar</div>
                    <button onClick={() => setShowAttach(false)} aria-label="Cerrar" style={{ background: "none", border: "none", color: C.text2 }}><X size={18} /></button>
                  </div>
                  <div style={{ display: "flex", gap: 12 }}>
                    <button onClick={() => setShowAttach(false)} style={{ flex: 1, background: C.card, border: `1px solid ${C.line}`, borderRadius: 14, padding: "16px 10px", display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
                      <div style={{ width: 38, height: 38, borderRadius: 12, background: "rgba(43,184,159,0.14)", display: "flex", alignItems: "center", justifyContent: "center" }}><ImageIcon size={18} color={C.teal} /></div>
                      <span style={{ fontSize: 11.5, fontWeight: 600 }}>Foto</span>
                    </button>
                    <button onClick={() => setShowAttach(false)} style={{ flex: 1, background: C.card, border: `1px solid ${C.line}`, borderRadius: 14, padding: "16px 10px", display: "flex", flexDirection: "column", alignItems: "center", gap: 8 }}>
                      <div style={{ width: 38, height: 38, borderRadius: 12, background: "rgba(43,184,159,0.14)", display: "flex", alignItems: "center", justifyContent: "center" }}><MapPin size={18} color={C.teal} /></div>
                      <span style={{ fontSize: 11.5, fontWeight: 600 }}>Ubicación</span>
                    </button>
                  </div>
                  <div style={{ fontSize: 10.5, color: C.text3, marginTop: 14, lineHeight: 1.5 }}>
                    Los archivos se comparten directo entre los dispositivos conectados a la red local, no pasan por Internet.
                  </div>
                </Overlay>
              )}
            </div>
          )}

          {screen === "participantes" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column" }}>
              <TopBar title="Participantes" subtitle="2 conectados" onBack={back} />
              <div style={{ padding: "14px 16px", flex: 1 }}>
                <ParticipantRow name={profile.name || "Vos"} color={profile.color} host strength={4} />
                <ParticipantRow name="Solchi" color={AVATAR_COLORS[1]} strength={3} />
                <div style={{ marginTop: 18 }}>
                  <GhostButton onClick={() => {}}><Crown size={15} /> Transferir anfitrión</GhostButton>
                </div>
              </div>
            </div>
          )}

          {screen === "config-sala" && (
            <div style={{ flex: 1, display: "flex", flexDirection: "column", position: "relative" }}>
              <TopBar title="Configuración" onBack={back} />
              <div style={{ padding: "18px 16px", flex: 1, display: "flex", flexDirection: "column", gap: 10 }}>
                <ConfigRow icon={<Pencil size={16} color={C.teal} />} label="Renombrar sala" />
                <ConfigRow icon={<QrCode size={16} color={C.teal} />} label="Ver código y QR" onClick={() => go("sala-creada")} />
                <ConfigRow icon={<Crown size={16} color={C.teal} />} label="Transferir anfitrión" onClick={() => go("participantes")} />
                <div style={{ marginTop: "auto", display: "flex", flexDirection: "column", gap: 10 }}>
                  <GhostButton onClick={() => setConfirmAction("salir")}><LogOut size={15} /> Salir de la sala</GhostButton>
                  <GhostButton danger onClick={() => setConfirmAction("finalizar")}><Trash2 size={15} /> Finalizar sala</GhostButton>
                </div>
              </div>

              {confirmAction && (
                <CenterModal>
                  <div style={{ fontSize: 14.5, fontWeight: 700, marginBottom: 8 }}>
                    {confirmAction === "salir" ? "¿Salir de la sala?" : "¿Finalizar la sala para todos?"}
                  </div>
                  <div style={{ fontSize: 12, color: C.text2, lineHeight: 1.5, marginBottom: 18 }}>
                    {confirmAction === "salir"
                      ? "Vas a dejar de ver los mensajes hasta que te vuelvas a unir con el código."
                      : "Se va a cerrar la sala para todos los participantes y se va a perder el historial del chat."}
                  </div>
                  <div style={{ display: "flex", gap: 10 }}>
                    <div style={{ flex: 1 }}><GhostButton onClick={() => setConfirmAction(null)}>Cancelar</GhostButton></div>
                    <div style={{ flex: 1 }}>
                      <PrimaryButton
                        style={confirmAction === "finalizar" ? { background: C.red } : {}}
                        onClick={() => { setConfirmAction(null); resetTo("home"); }}
                      >
                        {confirmAction === "salir" ? "Salir" : "Finalizar"}
                      </PrimaryButton>
                    </div>
                  </div>
                </CenterModal>
              )}
            </div>
          )}

        </div>
      </div>
    </div>
  );
}

function RowCard({ icon, title, sub, onClick }) {
  return (
    <button onClick={onClick} style={{
      width: "100%", background: C.card, border: `1px solid ${C.line}`, borderRadius: 14,
      padding: "13px 14px", display: "flex", alignItems: "center", gap: 12, marginBottom: 10, cursor: "pointer",
    }}>
      <div style={{ width: 34, height: 34, borderRadius: 10, background: "rgba(43,184,159,0.14)", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
        {icon}
      </div>
      <div style={{ flex: 1, textAlign: "left" }}>
        <div style={{ fontSize: 13.5, fontWeight: 700 }}>{title}</div>
        <div style={{ fontSize: 11, color: C.text2, marginTop: 1 }}>{sub}</div>
      </div>
      <ChevronRight size={16} color={C.text3} />
    </button>
  );
}

function ChannelRow({ name, sub, unread, onClick }) {
  return (
    <button onClick={onClick} style={{
      width: "100%", background: "none", border: "none", borderBottom: `1px solid ${C.line}`,
      padding: "12px 2px", display: "flex", alignItems: "center", gap: 12, cursor: "pointer",
    }}>
      <div style={{
        width: 38, height: 38, borderRadius: 12, flexShrink: 0,
        background: `linear-gradient(135deg, ${C.teal}, ${C.sky})`,
        display: "flex", alignItems: "center", justifyContent: "center",
      }}>
        <Users size={16} color="#fff" />
      </div>
      <div style={{ flex: 1, textAlign: "left", minWidth: 0 }}>
        <div style={{ fontSize: 13.5, fontWeight: 700 }}>{name}</div>
        <div style={{ fontSize: 11.5, color: C.text2, whiteSpace: "nowrap", overflow: "hidden", textOverflow: "ellipsis" }}>{sub}</div>
      </div>
      {unread > 0 && (
        <div style={{ minWidth: 18, height: 18, borderRadius: 9, background: C.teal, color: "#fff", fontSize: 10, fontWeight: 700, display: "flex", alignItems: "center", justifyContent: "center", padding: "0 5px" }}>
          {unread}
        </div>
      )}
    </button>
  );
}

function ParticipantRow({ name, color, host, strength }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 12, padding: "11px 2px", borderBottom: `1px solid ${C.line}` }}>
      <Avatar color={color} initial={name[0]} size={34} />
      <div style={{ flex: 1 }}>
        <div style={{ fontSize: 13.5, fontWeight: 700, display: "flex", alignItems: "center", gap: 6 }}>
          {name} {host && <Crown size={12} color={C.teal} />}
        </div>
        <div style={{ fontSize: 10.5, color: C.text2 }}>{host ? "Anfitrión" : "Participante"}</div>
      </div>
      <SignalBar strength={strength} />
    </div>
  );
}

function ConfigRow({ icon, label, onClick }) {
  return (
    <button onClick={onClick} style={{
      width: "100%", background: C.card, border: `1px solid ${C.line}`, borderRadius: 12,
      padding: "13px 14px", display: "flex", alignItems: "center", gap: 12, cursor: "pointer",
    }}>
      <div style={{ width: 30, height: 30, borderRadius: 9, background: "rgba(43,184,159,0.14)", display: "flex", alignItems: "center", justifyContent: "center" }}>
        {icon}
      </div>
      <div style={{ flex: 1, textAlign: "left", fontSize: 13.5, fontWeight: 600 }}>{label}</div>
      <ChevronRight size={16} color={C.text3} />
    </button>
  );
}
