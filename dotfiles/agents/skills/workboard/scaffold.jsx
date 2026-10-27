// Live React instruments keyed by `demoKey`.
const DEMOS = {};

// Unified git diffs keyed by `diffKey` or `item.id`.
const DIFFS = {};

export default function Workboard() {
  const [activity, setActivity] = useMorph({
    state: "idle",
    summary: "Board ready.",
    sectionId: null,
    updatedAt: null,
  });

  const [entries, setEntries] = useMorph({
    "step-overview": {
      id: "step-overview",
      code: null,
      order: 0,
      title: "Overview & Summary",
      status: "to-review",
      summary: "Project overview and section directory.",
      tldr: "Select a section in the sidebar or directory below to inspect tasks, decisions, demos, and diffs.",
      blocks: [
        {
          id: "ov-directory",
          heading: "Sections",
          items: [{ id: "ov-dir-item", kind: "directory" }],
        },
      ],
    },
  });

  const [threads, setThreads] = useMorph({});

  const [view, setView] = useMorph({
    selectedId: "step-overview",
    stages: {},
    diffOpen: {},
  });

  return (
    <WorkboardShell
      activity={activity}
      setActivity={setActivity}
      entries={entries}
      setEntries={setEntries}
      threads={threads}
      setThreads={setThreads}
      view={view}
      setView={setView}
    />
  );
}

/* ========================================================================== */
/* UI TOOLKIT (HOISTED)                                                       */
/* ========================================================================== */

function WorkboardShell({
  activity,
  entries,
  setEntries,
  threads,
  setThreads,
  view,
  setView,
}) {
  const [mobileNavOpen, setMobileNavOpen] = useState(false);
  const [navSeq, setNavSeq] = useState(0);
  const scrollTargetRef = useRef(null);
  const mainRef = useRef(null);

  const entryList = Object.values(entries || {}).sort(
    (a, b) => (a.order ?? 99) - (b.order ?? 99),
  );

  const rawSelectedId =
    view && view.selectedId ? view.selectedId : "step-overview";
  const currentEntry =
    rawSelectedId === "__discussions__"
      ? null
      : entryList.find((e) => e.id === rawSelectedId) || entryList[0] || null;
  const selectedId =
    rawSelectedId === "__discussions__"
      ? "__discussions__"
      : currentEntry
        ? currentEntry.id
        : rawSelectedId;

  const handleNavigate = (entryId, blockId = null) => {
    scrollTargetRef.current = blockId || null;
    setView((draft) => {
      draft.selectedId = entryId;
      if (blockId) {
        const diffMatch = /^(.+)::(?:line|file)::([^:]+)/.exec(blockId);
        if (diffMatch) {
          if (!draft.diffOpen) draft.diffOpen = {};
          draft.diffOpen[`${diffMatch[1]}::${diffMatch[2]}`] = true;
        }
      }
    });
    setMobileNavOpen(false);
    setNavSeq((n) => n + 1);
  };

  useEffect(() => {
    const targetBlockId = scrollTargetRef.current;
    scrollTargetRef.current = null;
    if (targetBlockId) {
      const timer = setTimeout(() => {
        const el = document.getElementById(targetBlockId);
        if (el) {
          el.scrollIntoView({ behavior: "smooth", block: "center" });
        }
      }, 60);
      return () => clearTimeout(timer);
    }
    if (mainRef.current) {
      mainRef.current.scrollTop = 0;
    }
  }, [selectedId, navSeq]);

  const handleAddComment = ({ entryId, itemId, blockHeading, text }) => {
    const msg = {
      id: "c-" + Date.now() + "-" + Math.random().toString(36).slice(2, 6),
      from: "user",
      entryId,
      blockHeading,
      text,
      createdAt: new Date().toISOString(),
    };
    setThreads((draft) => {
      if (!draft[itemId]) draft[itemId] = [];
      draft[itemId].push(msg);
    });
  };

  const handleStatusChange = (entryId, nextStatus) => {
    setEntries((draft) => {
      if (draft[entryId]) {
        draft[entryId].status = nextStatus;
      }
    });
  };

  const handleSelectDecision = (entryId, itemId, optionId) => {
    setEntries((draft) => {
      const current = draft[entryId];
      if (!current || !Array.isArray(current.blocks)) return;
      for (const b of current.blocks) {
        for (const it of b.items || []) {
          if (it && it.id === itemId) {
            it.selected = optionId;
            return;
          }
        }
      }
    });
  };

  const handleTaskStatusChange = (entryId, itemId, taskId, next) => {
    setEntries((draft) => {
      const current = draft[entryId];
      if (!current || !Array.isArray(current.blocks)) return;
      for (const b of current.blocks) {
        for (const it of b.items || []) {
          if (it && it.id === itemId && Array.isArray(it.items)) {
            const task = it.items.find((t) => t && t.id === taskId);
            if (task) {
              task.status = next;
              return;
            }
          }
        }
      }
    });
  };

  const handleStageChange = (itemId, stageId) => {
    setView((draft) => {
      if (!draft.stages) draft.stages = {};
      draft.stages[itemId] = stageId;
    });
  };

  const handleDiffFilesSet = (fileKeys, nextOpen) => {
    setView((draft) => {
      if (!draft.diffOpen) draft.diffOpen = {};
      for (const k of fileKeys) {
        draft.diffOpen[k] = nextOpen;
      }
    });
  };

  return (
    <div className="flex h-screen w-screen flex-col overflow-hidden bg-white font-sans text-zinc-900 dark:bg-zinc-950 dark:text-zinc-100">
      <style>{`
        html, body { background: #ffffff; color: #18181b; }
        @media (prefers-color-scheme: dark) {
          html, body { background: #09090b; color: #f4f4f5; }
        }
      `}</style>

      <ActivityBanner
        activity={activity}
        entryList={entryList}
        onSelectEntry={(id) => handleNavigate(id, null)}
      />

      <div className="flex min-h-0 flex-1 flex-col overflow-hidden md:flex-row">
        <MobileTopBar
          entryList={entryList}
          selectedId={selectedId}
          currentEntry={currentEntry}
          threads={threads}
          onOpenMenu={() => setMobileNavOpen(true)}
          onSelect={(id) => handleNavigate(id, null)}
        />

        {mobileNavOpen ? (
          <div className="fixed inset-0 z-40 flex md:hidden">
            <button
              type="button"
              aria-label="Close navigation backdrop"
              onClick={() => setMobileNavOpen(false)}
              className="fixed inset-0 bg-zinc-900/40 dark:bg-black/60"
            />
            <div className="relative z-10 h-full">
              <SidebarNav
                entryList={entryList}
                selectedId={selectedId}
                onSelect={(id) => handleNavigate(id, null)}
                threads={threads}
                mobile
                onClose={() => setMobileNavOpen(false)}
              />
            </div>
          </div>
        ) : null}

        <SidebarNav
          entryList={entryList}
          selectedId={selectedId}
          onSelect={(id) => handleNavigate(id, null)}
          threads={threads}
        />

        <EntryDossier
          mainRef={mainRef}
          selectedId={selectedId}
          entry={currentEntry}
          entryList={entryList}
          threads={threads}
          view={view}
          onAddComment={handleAddComment}
          onSelectEntry={handleNavigate}
          onStatusChange={handleStatusChange}
          onSelectDecision={handleSelectDecision}
          onTaskStatusChange={handleTaskStatusChange}
          onStageChange={handleStageChange}
          onDiffFilesSet={handleDiffFilesSet}
        />
      </div>
    </div>
  );
}

function SvgIcon({ className = "h-4 w-4", children }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="2"
      strokeLinecap="round"
      strokeLinejoin="round"
      className={className}
    >
      {children}
    </svg>
  );
}

function MessageSquare({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="M21 15a2 2 0 0 1-2 2H7l-4 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z" />
    </SvgIcon>
  );
}

function Send({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="m22 2-7 20-4-9-9-4Z" />
      <path d="M22 2 11 13" />
    </SvgIcon>
  );
}

function FileCode2({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="M4 22h14a2 2 0 0 0 2-2V7l-5-5H6a2 2 0 0 0-2 2v4" />
      <path d="M14 2v4a2 2 0 0 0 2 2h4" />
      <path d="m5 12-3 3 3 3" />
      <path d="m9 18 3-3-3-3" />
    </SvgIcon>
  );
}

function ChevronDown({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="m6 9 6 6 6-6" />
    </SvgIcon>
  );
}

function ChevronRight({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="m9 18 6-6-6-6" />
    </SvgIcon>
  );
}

function ChevronLeft({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="m15 18-6-6 6-6" />
    </SvgIcon>
  );
}

function RefreshCw({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="M3 12a9 9 0 0 1 9-9 9.75 9.75 0 0 1 6.74 2.74L21 8" />
      <path d="M21 3v5h-5" />
      <path d="M21 12a9 9 0 0 1-9 9 9.75 9.75 0 0 1-6.74-2.74L3 16" />
      <path d="M8 16H3v5" />
    </SvgIcon>
  );
}

function ArrowUpRight({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="M7 7h10v10" />
      <path d="M7 17 17 7" />
    </SvgIcon>
  );
}

function LayoutList({ className }) {
  return (
    <SvgIcon className={className}>
      <rect width="7" height="7" x="3" y="3" rx="1" />
      <rect width="7" height="7" x="3" y="14" rx="1" />
      <path d="M14 4h7" />
      <path d="M14 9h7" />
      <path d="M14 15h7" />
      <path d="M14 20h7" />
    </SvgIcon>
  );
}

function CheckCircle2({ className }) {
  return (
    <SvgIcon className={className}>
      <circle cx="12" cy="12" r="10" />
      <path d="m9 12 2 2 4-4" />
    </SvgIcon>
  );
}

function AlertTriangle({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3" />
      <path d="M12 9v4" />
      <path d="M12 17h.01" />
    </SvgIcon>
  );
}

function Sparkles({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="M9.937 15.5A2 2 0 0 0 8.5 14.063l-6.135-1.582a.5.5 0 0 1 0-.962L8.5 9.936A2 2 0 0 0 9.937 8.5l1.582-6.135a.5.5 0 0 1 .963 0L14.063 8.5A2 2 0 0 0 15.5 9.937l6.135 1.581a.5.5 0 0 1 0 .964L15.5 14.063a2 2 0 0 0-1.437 1.437l-1.582 6.135a.5.5 0 0 1-.963 0z" />
    </SvgIcon>
  );
}

function Menu({ className }) {
  return (
    <SvgIcon className={className}>
      <line x1="4" x2="20" y1="12" y2="12" />
      <line x1="4" x2="20" y1="6" y2="6" />
      <line x1="4" x2="20" y1="18" y2="18" />
    </SvgIcon>
  );
}

function X({ className }) {
  return (
    <SvgIcon className={className}>
      <path d="M18 6 6 18" />
      <path d="m6 6 12 12" />
    </SvgIcon>
  );
}

function Clock({ className }) {
  return (
    <SvgIcon className={className}>
      <circle cx="12" cy="12" r="10" />
      <polyline points="12 6 12 12 16 14" />
    </SvgIcon>
  );
}

const DRAFTS = (window.__WORKBOARD_DRAFTS__ ??= {});

function useDraft(key) {
  const [value, setValue] = useState(() => DRAFTS[key] ?? "");
  const update = (next) => {
    if (next) DRAFTS[key] = next;
    else delete DRAFTS[key];
    setValue(next);
  };
  return [value, update];
}

const STATUS_OPTIONS = [
  {
    value: "planned",
    label: "Planned",
    pillClass:
      "border-zinc-200 bg-zinc-100 text-zinc-700 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300",
    dotClass: "bg-zinc-400 dark:bg-zinc-500",
  },
  {
    value: "working",
    label: "Working",
    pillClass:
      "border-blue-200 bg-blue-50 text-blue-800 dark:border-blue-800 dark:bg-blue-950/70 dark:text-blue-300",
    dotClass: "bg-blue-500",
  },
  {
    value: "to-review",
    label: "To Review",
    pillClass:
      "border-amber-200 bg-amber-50 text-amber-800 dark:border-amber-800 dark:bg-amber-950/70 dark:text-amber-300",
    dotClass: "bg-amber-500",
  },
  {
    value: "reviewed",
    label: "Reviewed",
    pillClass:
      "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-950/70 dark:text-emerald-300",
    dotClass: "bg-emerald-500",
  },
];

const TASK_STATUS_OPTIONS = [
  {
    value: "todo",
    label: "Todo",
    pillClass:
      "border-zinc-200 bg-zinc-100 text-zinc-700 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300",
    dotClass: "bg-zinc-400 dark:bg-zinc-500",
  },
  {
    value: "working",
    label: "Working",
    pillClass:
      "border-blue-200 bg-blue-50 text-blue-800 dark:border-blue-800 dark:bg-blue-950/70 dark:text-blue-300",
    dotClass: "bg-blue-500",
  },
  {
    value: "done",
    label: "Done",
    pillClass:
      "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-950/70 dark:text-emerald-300",
    dotClass: "bg-emerald-500",
  },
  {
    value: "blocked",
    label: "Blocked",
    pillClass:
      "border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-800 dark:bg-rose-950/70 dark:text-rose-300",
    dotClass: "bg-rose-500",
  },
];

function normalizeStatus(status) {
  if (status === "reviewed") return "reviewed";
  if (status === "working") return "working";
  if (status === "planned") return "planned";
  return "to-review";
}

function getStatusMeta(status) {
  const norm = normalizeStatus(status);
  return STATUS_OPTIONS.find((s) => s.value === norm) || STATUS_OPTIONS[2];
}

function normalizeTaskStatus(status) {
  if (status === "done") return "done";
  if (status === "working") return "working";
  if (status === "blocked") return "blocked";
  return "todo";
}

function getTaskStatusMeta(status) {
  const norm = normalizeTaskStatus(status);
  return (
    TASK_STATUS_OPTIONS.find((s) => s.value === norm) || TASK_STATUS_OPTIONS[0]
  );
}

function nextTaskStatus(status) {
  const norm = normalizeTaskStatus(status);
  if (norm === "todo") return "working";
  if (norm === "working") return "done";
  return "todo";
}

function isOverviewEntry(entry) {
  return Boolean(entry && entry.id === "step-overview");
}

function ActivityBanner({ activity, entryList, onSelectEntry }) {
  if (!activity || (!activity.summary && !activity.state)) return null;
  const state = activity.state || "idle";
  const targetEntry = activity.sectionId
    ? (entryList || []).find((e) => e.id === activity.sectionId)
    : null;

  const tone =
    state === "working"
      ? "border-blue-200 bg-blue-50/80 text-blue-900 dark:border-blue-900/70 dark:bg-blue-950/50 dark:text-blue-200"
      : state === "waiting"
        ? "border-amber-200 bg-amber-50/80 text-amber-900 dark:border-amber-900/70 dark:bg-amber-950/50 dark:text-amber-200"
        : "border-zinc-200 bg-zinc-50 text-zinc-700 dark:border-zinc-800 dark:bg-zinc-900/80 dark:text-zinc-300";

  const dot =
    state === "working"
      ? "bg-blue-500 animate-pulse"
      : state === "waiting"
        ? "bg-amber-500"
        : "bg-emerald-500";

  const label =
    state === "working"
      ? "Agent Working"
      : state === "waiting"
        ? "Waiting on You"
        : "Agent Idle";

  return (
    <div
      className={`flex shrink-0 flex-wrap items-center justify-between gap-2 border-b px-3.5 py-1.5 text-xs ${tone}`}
    >
      <div className="flex min-w-0 items-center gap-2">
        <span className={`h-2 w-2 shrink-0 rounded-full ${dot}`} />
        <span className="shrink-0 font-mono text-[11px] font-semibold uppercase tracking-wider">
          {label}
        </span>
        {activity.summary ? (
          <span className="truncate font-medium">{activity.summary}</span>
        ) : null}
      </div>

      <div className="flex shrink-0 items-center gap-2.5">
        {targetEntry ? (
          <button
            type="button"
            onClick={() => onSelectEntry(targetEntry.id)}
            className="inline-flex cursor-pointer items-center gap-1 rounded border border-current/20 bg-white/60 px-2 py-0.5 font-mono text-[11px] font-semibold hover:bg-white dark:bg-zinc-900/60 dark:hover:bg-zinc-900"
          >
            <span>
              {targetEntry.code
                ? `${targetEntry.code} ${targetEntry.title}`
                : targetEntry.title}
            </span>
            <ArrowUpRight className="h-3 w-3" />
          </button>
        ) : null}
        {activity.updatedAt ? (
          <span className="inline-flex items-center gap-1 font-mono text-[11px] opacity-70">
            <Clock className="h-3 w-3" />
            {formatShortTime(activity.updatedAt)}
          </span>
        ) : null}
      </div>
    </div>
  );
}

function StatusBadge({ status }) {
  const meta = getStatusMeta(status);
  return (
    <span
      className={`inline-flex items-center gap-1.5 rounded-full border px-2 py-0.5 font-sans text-[11px] font-medium ${meta.pillClass}`}
    >
      <span className={`h-1.5 w-1.5 rounded-full ${meta.dotClass}`} />
      {meta.label}
    </span>
  );
}

function StatusPicker({ status, onChange }) {
  const norm = normalizeStatus(status);
  return (
    <div className="inline-flex flex-wrap items-center rounded-lg border border-zinc-200 bg-zinc-100/80 p-0.5 dark:border-zinc-800 dark:bg-zinc-900">
      {STATUS_OPTIONS.map((opt) => {
        const active = norm === opt.value;
        return (
          <button
            key={opt.value}
            type="button"
            onClick={() => onChange(opt.value)}
            className={`inline-flex cursor-pointer items-center gap-1.5 rounded-md px-2 py-1 text-[11px] font-medium transition-all sm:px-2.5 sm:text-xs ${
              active
                ? "bg-white text-zinc-900 shadow-2xs ring-1 ring-zinc-200 dark:bg-zinc-800 dark:text-zinc-100 dark:ring-zinc-700"
                : "text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
            }`}
          >
            <span className={`h-1.5 w-1.5 rounded-full ${opt.dotClass}`} />
            {opt.label}
          </button>
        );
      })}
    </div>
  );
}

function resolveAuthorName(record) {
  if (!record) return "You";
  if (record.author) return record.author;
  return record.from === "agent" ? "Agent" : "You";
}

function isAgentMessage(record) {
  return Boolean(record && record.from === "agent");
}

function formatShortTime(iso) {
  if (!iso) return "";
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return String(iso);
  return d.toLocaleTimeString([], {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });
}

function tokenColorClass(type) {
  switch (type) {
    case "comment":
      return "italic text-zinc-400 dark:text-zinc-500";
    case "string":
      return "text-emerald-700 dark:text-emerald-400";
    case "keyword":
      return "font-medium text-violet-700 dark:text-violet-400";
    case "function":
      return "text-blue-700 dark:text-blue-400";
    case "number":
    case "boolean":
      return "text-amber-700 dark:text-amber-400";
    case "class-name":
      return "text-sky-700 dark:text-sky-400";
    case "operator":
      return "text-rose-700 dark:text-rose-400";
    case "punctuation":
      return "text-zinc-500 dark:text-zinc-400";
    default:
      return "";
  }
}

const CODE_TOKEN_RE =
  /(\/\/.*$|\/\*[\s\S]*?\*\/)|("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)|\b(import|export|from|default|const|let|var|function|return|if|else|for|while|switch|case|break|continue|new|typeof|instanceof|async|await|try|catch|finally|throw|class|extends|type|interface)\b|\b(true|false|null|undefined|NaN|Infinity)\b|\b(\d+(?:\.\d+)?)\b|\b([A-Z][A-Za-z0-9_]*)\b|\b([a-zA-Z_$][a-zA-Z0-9_$]*)(?=\s*\()|([+\-*/%=&|<>!?:]+)|([{}()[\].,;])/gm;

function HighlightedCodeLine({ text }) {
  if (!text) return " ";
  const str = String(text);
  const out = [];
  let lastIdx = 0;
  CODE_TOKEN_RE.lastIndex = 0;
  let m;
  let k = 0;
  while ((m = CODE_TOKEN_RE.exec(str)) !== null) {
    if (m.index > lastIdx) {
      out.push(str.slice(lastIdx, m.index));
    }
    const [
      full,
      comment,
      stringLit,
      keyword,
      boolLit,
      numLit,
      className,
      fnName,
      operator,
      punct,
    ] = m;
    const type = comment
      ? "comment"
      : stringLit
        ? "string"
        : keyword
          ? "keyword"
          : boolLit
            ? "boolean"
            : numLit
              ? "number"
              : className
                ? "class-name"
                : fnName
                  ? "function"
                  : operator
                    ? "operator"
                    : punct
                      ? "punctuation"
                      : "";
    out.push(
      <span key={k++} className={tokenColorClass(type)}>
        {full}
      </span>,
    );
    lastIdx = m.index + full.length;
  }
  if (lastIdx < str.length) {
    out.push(str.slice(lastIdx));
  }
  return out;
}

function SyntaxHighlightedBlock({ body, compact }) {
  const lines = String(body || "")
    .replace(/\n$/, "")
    .split("\n");
  return (
    <pre
      style={{ overflowWrap: "anywhere" }}
      className={`overflow-x-auto font-mono text-xs leading-5 whitespace-pre-wrap text-zinc-800 dark:text-zinc-200 ${
        compact
          ? "my-2.5 rounded-lg border border-zinc-200 bg-zinc-50 p-3.5 dark:border-zinc-800 dark:bg-zinc-900"
          : "flex-1 p-3.5"
      }`}
    >
      {lines.map((line, idx) => (
        <div key={idx} className="min-w-0">
          <HighlightedCodeLine text={line} />
        </div>
      ))}
    </pre>
  );
}

function TaskCheckboxBadge({ checked }) {
  return (
    <span
      role="checkbox"
      aria-checked={checked}
      className={`mr-1.5 inline-flex h-4 w-4 shrink-0 translate-y-0.5 items-center justify-center rounded border ${
        checked
          ? "border-blue-600 bg-blue-600 text-white"
          : "border-zinc-300 bg-white text-transparent dark:border-zinc-600 dark:bg-zinc-900"
      }`}
    >
      <svg
        viewBox="0 0 12 12"
        className="h-2.5 w-2.5"
        fill="none"
        stroke="currentColor"
        strokeWidth="2"
        strokeLinecap="round"
        strokeLinejoin="round"
      >
        <path d="M2.5 6.5 5 9l4.5-5.5" />
      </svg>
    </span>
  );
}

function renderCheckboxCodeBadge(raw) {
  const trimmed = String(raw || "").trim();
  if (trimmed === "[x]" || trimmed === "[X]") {
    return <TaskCheckboxBadge checked={true} />;
  }
  if (trimmed === "[ ]") {
    return <TaskCheckboxBadge checked={false} />;
  }
  return null;
}

const markdownComponents = {
  h1: ({ children }) => (
    <h4 className="mt-3 mb-1.5 text-base font-bold text-zinc-900 first:mt-0 dark:text-zinc-100">
      {children}
    </h4>
  ),
  h2: ({ children }) => (
    <h4 className="mt-3 mb-1.5 text-[15px] font-semibold text-zinc-900 first:mt-0 dark:text-zinc-100">
      {children}
    </h4>
  ),
  h3: ({ children }) => (
    <h5 className="mt-2.5 mb-1 text-sm font-semibold text-zinc-900 first:mt-0 dark:text-zinc-100">
      {children}
    </h5>
  ),
  h4: ({ children }) => (
    <h6 className="mt-2 mb-1 text-xs font-semibold tracking-wide text-zinc-700 uppercase first:mt-0 dark:text-zinc-300">
      {children}
    </h6>
  ),
  blockquote: ({ children }) => (
    <blockquote className="my-2.5 rounded-r-lg border-l-2 border-blue-500 bg-zinc-50 px-3.5 py-2.5 text-[14px] leading-6 text-zinc-700 dark:bg-zinc-900 dark:text-zinc-300">
      {children}
    </blockquote>
  ),
  p: ({ children }) => (
    <p className="mb-2.5 text-[15px] leading-7 text-zinc-700 last:mb-0 dark:text-zinc-300">
      {children}
    </p>
  ),
  strong: ({ children }) => (
    <strong className="font-semibold text-zinc-900 dark:text-zinc-100">
      {children}
    </strong>
  ),
  em: ({ children }) => (
    <em className="text-zinc-600 italic dark:text-zinc-400">{children}</em>
  ),
  del: ({ children }) => (
    <del className="text-zinc-400 line-through dark:text-zinc-500">
      {children}
    </del>
  ),
  a: ({ href, children }) => (
    <a
      href={href}
      target="_blank"
      rel="noreferrer"
      className="font-medium text-blue-600 underline decoration-blue-300 underline-offset-2 hover:text-blue-700 dark:text-blue-400 dark:decoration-blue-700"
    >
      {children}
    </a>
  ),
  ul: ({ isTaskList, children }) => (
    <ul
      className={`my-2 space-y-1.5 text-[15px] leading-7 text-zinc-700 dark:text-zinc-300 ${
        isTaskList ? "list-none pl-1" : "list-disc pl-5"
      }`}
    >
      {children}
    </ul>
  ),
  ol: ({ start, children }) => (
    <ol
      start={start}
      className="my-2 list-decimal space-y-1.5 pl-5 text-[15px] leading-7 text-zinc-700 dark:text-zinc-300"
    >
      {children}
    </ol>
  ),
  li: ({ isTask, children }) => (
    <li className={isTask ? "pl-0" : "pl-1"}>{children}</li>
  ),
  pre: ({ children }) => <>{children}</>,
  code: ({ className, children }) => {
    const raw = String(children || "");
    const isBlock = Boolean(className) || raw.includes("\n");
    if (isBlock) {
      return <SyntaxHighlightedBlock body={raw} compact />;
    }
    const badge = renderCheckboxCodeBadge(raw);
    if (badge) return badge;
    return (
      <code className="rounded-md border border-zinc-200/80 bg-zinc-100 px-1.5 py-0.5 font-mono text-[12.5px] font-medium text-zinc-800 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-200">
        {children}
      </code>
    );
  },
};

const inlineMarkdownComponents = {
  ...markdownComponents,
  p: ({ children }) => <>{children}</>,
  code: ({ children }) => {
    const badge = renderCheckboxCodeBadge(children);
    if (badge) return badge;
    return (
      <code className="rounded border border-zinc-200/80 bg-zinc-100 px-1 py-0.5 font-mono text-[11px] font-medium text-zinc-800 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-200">
        {children}
      </code>
    );
  },
};

const INLINE_MD_RE =
  /(`[^`]+`|\*\*[^*]+\*\*|~~[^~]+~~|\*[^*\n]+\*|\[[^\]]+\]\([^)]+\))/g;

function renderInlineMarkdown(text, components) {
  const str = String(text || "");
  const parts = str.split(INLINE_MD_RE);
  const CodeComp = components.code;
  const StrongComp = components.strong;
  const EmComp = components.em;
  const DelComp = components.del;
  const AComp = components.a;
  return parts.map((part, i) => {
    if (!part) return null;
    if (part.startsWith("`") && part.endsWith("`") && part.length >= 2) {
      return <CodeComp key={i}>{part.slice(1, -1)}</CodeComp>;
    }
    if (part.startsWith("**") && part.endsWith("**") && part.length >= 4) {
      return (
        <StrongComp key={i}>
          {renderInlineMarkdown(part.slice(2, -2), components)}
        </StrongComp>
      );
    }
    if (part.startsWith("~~") && part.endsWith("~~") && part.length >= 4) {
      return (
        <DelComp key={i}>
          {renderInlineMarkdown(part.slice(2, -2), components)}
        </DelComp>
      );
    }
    if (part.startsWith("*") && part.endsWith("*") && part.length >= 2) {
      return (
        <EmComp key={i}>
          {renderInlineMarkdown(part.slice(1, -1), components)}
        </EmComp>
      );
    }
    const linkMatch = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(part);
    if (linkMatch) {
      return (
        <AComp key={i} href={linkMatch[2]}>
          {linkMatch[1]}
        </AComp>
      );
    }
    return part;
  });
}

function parseTaskListItem(text) {
  const m = /^\[([ xX])\]\s+(.*)$/.exec(String(text || "").trim());
  if (!m) return null;
  return {
    checked: m[1].toLowerCase() === "x",
    body: m[2],
  };
}

function ReactMarkdown({ children, components = markdownComponents }) {
  const raw = String(children || "");
  if (components === inlineMarkdownComponents) {
    return <>{renderInlineMarkdown(raw, components)}</>;
  }

  const lines = raw.split("\n");
  const blocks = [];
  let i = 0;

  while (i < lines.length) {
    const line = lines[i];
    if (!line.trim()) {
      i++;
      continue;
    }

    const fenceMatch = /^\s*```(\S*)/.exec(line);
    if (fenceMatch) {
      const lang = fenceMatch[1] || "js";
      i++;
      const codeLines = [];
      while (i < lines.length && !/^\s*```/.test(lines[i])) {
        codeLines.push(lines[i]);
        i++;
      }
      if (i < lines.length) i++;
      blocks.push({
        kind: "code",
        lang,
        body: codeLines.join("\n"),
      });
      continue;
    }

    const headingMatch = /^\s*(#{1,4})\s+(.*)$/.exec(line);
    if (headingMatch) {
      blocks.push({
        kind: `h${headingMatch[1].length}`,
        text: headingMatch[2].trim(),
      });
      i++;
      continue;
    }

    if (/^\s*>\s?/.test(line)) {
      const qLines = [];
      while (i < lines.length && /^\s*>\s?/.test(lines[i])) {
        qLines.push(lines[i].replace(/^\s*>\s?/, ""));
        i++;
      }
      blocks.push({ kind: "blockquote", text: qLines.join("\n") });
      continue;
    }

    if (/^\s*[-*]\s+/.test(line)) {
      const items = [];
      while (i < lines.length && /^\s*[-*]\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\s*[-*]\s+/, ""));
        i++;
      }
      blocks.push({ kind: "ul", items });
      continue;
    }

    const olMatch = /^\s*(\d+)\.\s+(.*)$/.exec(line);
    if (olMatch) {
      const start = Number.parseInt(olMatch[1], 10);
      const items = [];
      while (i < lines.length && /^\s*\d+\.\s+/.test(lines[i])) {
        items.push(lines[i].replace(/^\s*\d+\.\s+/, ""));
        i++;
      }
      blocks.push({ kind: "ol", start, items });
      continue;
    }

    const pLines = [];
    while (
      i < lines.length &&
      lines[i].trim() &&
      !/^\s*```/.test(lines[i]) &&
      !/^\s*#{1,4}\s+/.test(lines[i]) &&
      !/^\s*>\s?/.test(lines[i]) &&
      !/^\s*[-*]\s+/.test(lines[i]) &&
      !/^\s*\d+\.\s+/.test(lines[i])
    ) {
      pLines.push(lines[i]);
      i++;
    }
    blocks.push({ kind: "p", text: pLines.join(" ") });
  }

  const PComp = components.p;
  const UlComp = components.ul;
  const OlComp = components.ol;
  const LiComp = components.li;
  const CodeComp = components.code;
  const BlockquoteComp = components.blockquote;

  return (
    <>
      {blocks.map((b, idx) => {
        if (b.kind === "code") {
          return (
            <CodeComp key={idx} className={`language-${b.lang}`}>
              {b.body}
            </CodeComp>
          );
        }
        if (
          b.kind === "h1" ||
          b.kind === "h2" ||
          b.kind === "h3" ||
          b.kind === "h4"
        ) {
          const HComp = components[b.kind] || PComp;
          return (
            <HComp key={idx}>{renderInlineMarkdown(b.text, components)}</HComp>
          );
        }
        if (b.kind === "blockquote") {
          return (
            <BlockquoteComp key={idx}>
              <ReactMarkdown components={components}>{b.text}</ReactMarkdown>
            </BlockquoteComp>
          );
        }
        if (b.kind === "ul") {
          const parsedTasks = b.items.map(parseTaskListItem);
          const isTaskList = parsedTasks.some(Boolean);
          return (
            <UlComp key={idx} isTaskList={isTaskList}>
              {b.items.map((it, li) => {
                const taskItem = parsedTasks[li];
                if (taskItem) {
                  return (
                    <LiComp key={li} isTask>
                      <TaskCheckboxBadge checked={taskItem.checked} />
                      {renderInlineMarkdown(taskItem.body, components)}
                    </LiComp>
                  );
                }
                return (
                  <LiComp key={li}>
                    {renderInlineMarkdown(it, components)}
                  </LiComp>
                );
              })}
            </UlComp>
          );
        }
        if (b.kind === "ol") {
          return (
            <OlComp key={idx} start={b.start}>
              {b.items.map((it, li) => (
                <LiComp key={li}>{renderInlineMarkdown(it, components)}</LiComp>
              ))}
            </OlComp>
          );
        }
        return (
          <PComp key={idx}>{renderInlineMarkdown(b.text, components)}</PComp>
        );
      })}
    </>
  );
}

function parseTableCells(line) {
  const trimmed = line.trim().replace(/^\|/, "").replace(/\|$/, "");
  const cells = [];
  let cur = "";
  let inCode = false;
  for (let i = 0; i < trimmed.length; i++) {
    const ch = trimmed[i];
    if (ch === "\\" && i + 1 < trimmed.length) {
      const next = trimmed[i + 1];
      if (next === "|" || next === "`" || next === "\\") {
        cur += next;
        i++;
        continue;
      }
    }
    if (ch === "`") {
      inCode = !inCode;
      cur += ch;
      continue;
    }
    if (ch === "|" && !inCode) {
      cells.push(cur.trim());
      cur = "";
      continue;
    }
    cur += ch;
  }
  cells.push(cur.trim());
  return cells;
}

function isTableSeparatorLine(line) {
  const trimmed = line.trim();
  if (!trimmed.includes("|")) return false;
  const cells = parseTableCells(trimmed);
  return cells.length > 0 && cells.every((c) => /^:?-{2,}:?$/.test(c));
}

function splitMarkdownSegments(rawText) {
  const lines = String(rawText || "").split("\n");
  const segments = [];
  let mdLines = [];
  let inFence = false;
  let i = 0;

  const flushMd = () => {
    if (mdLines.length > 0) {
      segments.push({ kind: "markdown", text: mdLines.join("\n") });
      mdLines = [];
    }
  };

  while (i < lines.length) {
    const line = lines[i];
    if (/^\s*```/.test(line)) {
      inFence = !inFence;
      mdLines.push(line);
      i++;
      continue;
    }
    if (
      !inFence &&
      line.trim().startsWith("|") &&
      i + 1 < lines.length &&
      isTableSeparatorLine(lines[i + 1])
    ) {
      flushMd();
      const headers = parseTableCells(line);
      i += 2;
      const rows = [];
      while (
        i < lines.length &&
        lines[i].trim().startsWith("|") &&
        !isTableSeparatorLine(lines[i])
      ) {
        rows.push(parseTableCells(lines[i]));
        i++;
      }
      segments.push({ kind: "table", headers, rows });
      continue;
    }
    mdLines.push(line);
    i++;
  }
  flushMd();
  return segments;
}

function MarkdownWithTables({ children }) {
  const segments = splitMarkdownSegments(children);
  return (
    <>
      {segments.map((seg, idx) => {
        if (seg.kind === "table") {
          return (
            <div
              key={idx}
              className="my-3 overflow-x-auto rounded-lg border border-zinc-200 bg-white shadow-2xs dark:border-zinc-800 dark:bg-zinc-900"
            >
              <table className="w-full border-collapse text-left font-sans text-xs">
                <thead>
                  <tr className="border-b border-zinc-200 bg-zinc-50/90 text-zinc-700 dark:border-zinc-800 dark:bg-zinc-800/70 dark:text-zinc-300">
                    {seg.headers.map((h, hi) => (
                      <th
                        key={hi}
                        className="px-3 py-2 font-semibold whitespace-nowrap"
                      >
                        <ReactMarkdown components={inlineMarkdownComponents}>
                          {h}
                        </ReactMarkdown>
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody className="divide-y divide-zinc-200/80 dark:divide-zinc-800">
                  {seg.rows.map((row, ri) => (
                    <tr
                      key={ri}
                      className="hover:bg-zinc-50/60 dark:hover:bg-zinc-800/40"
                    >
                      {seg.headers.map((_, ci) => (
                        <td
                          key={ci}
                          className="px-3 py-2 align-top leading-5 text-zinc-700 dark:text-zinc-300"
                        >
                          <ReactMarkdown components={inlineMarkdownComponents}>
                            {String(row[ci] ?? "")}
                          </ReactMarkdown>
                        </td>
                      ))}
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          );
        }
        return (
          <ReactMarkdown key={idx} components={markdownComponents}>
            {seg.text}
          </ReactMarkdown>
        );
      })}
    </>
  );
}

function getBlockItems(block) {
  if (!block || !Array.isArray(block.items)) return [];
  return block.items.map((item, idx) => ({
    ...item,
    id: item.id || `${block.id}-item-${idx + 1}`,
    kind: item.kind || "prose",
    label:
      item.title ||
      item.label ||
      `${block.heading || block.id} (${item.id || idx + 1})`,
  }));
}

function getThreadList(threads, itemId) {
  if (!threads || !itemId) return [];
  const list = threads[itemId];
  return Array.isArray(list) ? list : [];
}

function itemHasComments(itemId, threads) {
  return getThreadList(threads, itemId).length > 0;
}

function itemHasPrefixComments(prefix, threads) {
  if (!threads || !prefix) return false;
  return Object.keys(threads).some(
    (k) =>
      k.startsWith(prefix) &&
      Array.isArray(threads[k]) &&
      threads[k].length > 0,
  );
}

function itemHasAnyComments(item, threads) {
  if (!item || !item.id) return false;
  if (itemHasComments(item.id, threads)) return true;
  if (item.kind === "diff" || item.kind === "tasks") {
    return itemHasPrefixComments(`${item.id}::`, threads);
  }
  return false;
}

function itemIsOpenDecision(item) {
  return Boolean(item && item.kind === "decision" && !item.selected);
}

function blockHasComments(block, threads) {
  return getBlockItems(block).some(
    (item) =>
      item.kind !== "directory" &&
      (itemHasAnyComments(item, threads) || itemIsOpenDecision(item)),
  );
}

function entryOpenDecisionCount(entry) {
  if (!entry) return 0;
  let count = 0;
  for (const block of entry.blocks || []) {
    for (const item of getBlockItems(block)) {
      if (itemIsOpenDecision(item)) count++;
    }
  }
  return count;
}

function entryTaskCounts(entry) {
  if (!entry) return { done: 0, total: 0 };
  let done = 0;
  let total = 0;
  for (const block of entry.blocks || []) {
    for (const item of getBlockItems(block)) {
      if (item.kind === "tasks" && Array.isArray(item.items)) {
        for (const t of item.items) {
          if (!t) continue;
          total++;
          if (normalizeTaskStatus(t.status) === "done") done++;
        }
      }
    }
  }
  return { done, total };
}

function resolveDiffRaw(item) {
  if (!item) return "";
  return (
    (item.diffKey && DIFFS[item.diffKey]) ||
    (item.id && DIFFS[item.id]) ||
    item.diff ||
    ""
  );
}

function isKnownEntryThreadId(entry, threadId) {
  if (!entry || !threadId) return false;
  if (entry.tldr && threadId === `${entry.id}-tldr`) return true;
  for (const block of entry.blocks || []) {
    for (const item of getBlockItems(block)) {
      if (!item.id) continue;
      if (threadId === item.id) return true;
      if (item.kind === "tasks" && Array.isArray(item.items)) {
        for (const t of item.items) {
          if (t && t.id && threadId === `${item.id}::task::${t.id}`) {
            return true;
          }
        }
      }
      if (item.kind === "diff" && threadId.startsWith(`${item.id}::`)) {
        const fileDiffs = splitUnifiedDiffByFile(
          resolveDiffRaw(item),
          item.file,
        );
        for (const fd of fileDiffs) {
          if (threadId === `${item.id}::file::${fd.file}`) return true;
          const linePrefix = `${item.id}::line::${fd.file}::L`;
          if (threadId.startsWith(linePrefix)) {
            const lineNum = Number.parseInt(
              threadId.slice(linePrefix.length),
              10,
            );
            if (lineNum >= 1 && lineNum <= fd.lineCount) return true;
          }
        }
      }
    }
  }
  return false;
}

function threadBelongsToEntryByPrefix(entry, threadId) {
  if (!entry || !threadId) return false;
  if (threadId === `${entry.id}-tldr`) return true;
  for (const block of entry.blocks || []) {
    for (const item of getBlockItems(block)) {
      if (!item.id) continue;
      if (threadId === item.id || threadId.startsWith(`${item.id}::`)) {
        return true;
      }
    }
  }
  return false;
}

function getEntryThreadBlockIds(entry, threads) {
  if (!entry || !threads) return [];
  const ids = [];
  for (const [anchorId, msgs] of Object.entries(threads)) {
    if (!Array.isArray(msgs) || msgs.length === 0) continue;
    const belongsByMeta = msgs.some((m) => m && m.entryId === entry.id);
    if (belongsByMeta || threadBelongsToEntryByPrefix(entry, anchorId)) {
      ids.push(anchorId);
    }
  }
  return ids;
}

function entryCommentedItemCount(entry, threads) {
  return getEntryThreadBlockIds(entry, threads).length;
}

function entryUnansweredCount(entry, threads) {
  const ids = getEntryThreadBlockIds(entry, threads);
  let count = 0;
  for (const id of ids) {
    const msgs = getThreadList(threads, id);
    const last = msgs[msgs.length - 1];
    if (last && !isAgentMessage(last)) count++;
  }
  return count;
}

function computeOpenThreadsCount(entryList, threads) {
  return (entryList || []).reduce((sum, entry) => {
    if (normalizeStatus(entry.status) === "reviewed") return sum;
    return (
      sum +
      entryCommentedItemCount(entry, threads) +
      entryOpenDecisionCount(entry)
    );
  }, 0);
}

function SidebarNav({
  entryList,
  selectedId,
  onSelect,
  threads,
  mobile = false,
  onClose = null,
}) {
  const overviewEntry =
    (entryList || []).find((e) => isOverviewEntry(e)) || null;
  const overviewId = overviewEntry ? overviewEntry.id : "step-overview";
  const overviewActive = selectedId === overviewId;
  const discussionsActive = selectedId === "__discussions__";
  const overviewComments = overviewEntry
    ? entryCommentedItemCount(overviewEntry, threads)
    : 0;
  const findingsList = (entryList || []).filter((e) => !isOverviewEntry(e));
  const openThreadsCount = computeOpenThreadsCount(entryList, threads);
  const reviewedCount = findingsList.filter(
    (e) => normalizeStatus(e.status) === "reviewed",
  ).length;
  const toReviewCount = findingsList.filter(
    (e) => normalizeStatus(e.status) === "to-review",
  ).length;

  return (
    <aside
      className={
        mobile
          ? "flex h-full w-72 max-w-[85vw] flex-col border-r border-zinc-200 bg-zinc-50 font-sans shadow-xl dark:border-zinc-800 dark:bg-zinc-900"
          : "hidden w-64 shrink-0 flex-col border-r border-zinc-200 bg-zinc-50/70 font-sans md:flex dark:border-zinc-800 dark:bg-zinc-900/50"
      }
    >
      <div className="space-y-1 border-b border-zinc-200 p-2.5 dark:border-zinc-800">
        {mobile && onClose ? (
          <div className="mb-1 flex items-center justify-between px-2 py-1">
            <span className="text-xs font-semibold text-zinc-500 dark:text-zinc-400">
              Sections
            </span>
            <button
              type="button"
              onClick={onClose}
              aria-label="Close navigation menu"
              className="cursor-pointer rounded-md p-1 text-zinc-500 hover:bg-zinc-200/70 hover:text-zinc-900 dark:text-zinc-400 dark:hover:bg-zinc-800 dark:hover:text-zinc-100"
            >
              <X className="h-4 w-4" />
            </button>
          </div>
        ) : null}

        <button
          type="button"
          onClick={() => onSelect(overviewId)}
          className={`flex w-full cursor-pointer items-center justify-between gap-2 rounded-lg px-3 py-2 text-left transition-colors ${
            overviewActive
              ? "bg-white text-zinc-900 shadow-2xs ring-1 ring-zinc-200/90 dark:bg-zinc-800 dark:text-zinc-100 dark:ring-zinc-700"
              : "text-zinc-600 hover:bg-zinc-100 hover:text-zinc-900 dark:text-zinc-400 dark:hover:bg-zinc-800/60 dark:hover:text-zinc-100"
          }`}
        >
          <div className="flex min-w-0 items-center gap-2.5">
            <LayoutList className="h-4 w-4 shrink-0 text-zinc-500 dark:text-zinc-400" />
            <div className="text-xs font-semibold">
              {overviewEntry ? overviewEntry.title : "Overview & Summary"}
            </div>
          </div>
          {overviewComments > 0 ? (
            <span className="inline-flex items-center gap-1 rounded-full bg-blue-50 px-1.5 py-0.5 font-mono text-[11px] font-semibold text-blue-700 ring-1 ring-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:ring-blue-800">
              <MessageSquare className="h-2.5 w-2.5" />
              {overviewComments}
            </span>
          ) : null}
        </button>

        <button
          type="button"
          onClick={() => onSelect("__discussions__")}
          className={`flex w-full cursor-pointer items-center justify-between gap-2 rounded-lg px-3 py-2 text-left transition-colors ${
            discussionsActive
              ? "bg-white text-zinc-900 shadow-2xs ring-1 ring-zinc-200/90 dark:bg-zinc-800 dark:text-zinc-100 dark:ring-zinc-700"
              : "text-zinc-600 hover:bg-zinc-100 hover:text-zinc-900 dark:text-zinc-400 dark:hover:bg-zinc-800/60 dark:hover:text-zinc-100"
          }`}
        >
          <div className="flex min-w-0 items-center gap-2.5">
            <MessageSquare className="h-4 w-4 shrink-0 text-blue-600 dark:text-blue-400" />
            <div className="text-xs font-semibold">Open Discussions</div>
          </div>
          <span
            className={`shrink-0 rounded-full px-2 py-0.5 font-mono text-[11px] font-semibold ${
              openThreadsCount > 0
                ? "bg-blue-600 text-white"
                : "bg-zinc-200 text-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
            }`}
          >
            {openThreadsCount}
          </span>
        </button>

        {findingsList.length > 0 ? (
          <div className="px-3 pt-1.5 pb-0.5 text-[11px] text-zinc-500 dark:text-zinc-400">
            <div className="flex items-center justify-between font-mono">
              <span>
                {reviewedCount}/{findingsList.length} reviewed
              </span>
              <span>{toReviewCount} to review</span>
            </div>
            <div className="mt-1 flex h-1.5 w-full overflow-hidden rounded-full bg-zinc-200 dark:bg-zinc-800">
              <div
                className="bg-emerald-500 transition-all"
                style={{
                  width: `${(reviewedCount / findingsList.length) * 100}%`,
                }}
              />
              <div
                className="bg-amber-400 transition-all"
                style={{
                  width: `${(toReviewCount / findingsList.length) * 100}%`,
                }}
              />
            </div>
          </div>
        ) : null}
      </div>

      <nav className="flex-1 overflow-y-auto px-2.5 py-2.5">
        <ul className="space-y-1">
          {findingsList.map((entry) => {
            const active = entry.id === selectedId;
            const entryComments = entryCommentedItemCount(entry, threads);
            const unanswered = entryUnansweredCount(entry, threads);
            const openDecisions = entryOpenDecisionCount(entry);
            const tasks = entryTaskCounts(entry);

            return (
              <li key={entry.id}>
                <button
                  type="button"
                  onClick={() => onSelect(entry.id)}
                  className={`w-full cursor-pointer rounded-lg px-3 py-2 text-left transition-colors ${
                    active
                      ? "bg-white text-zinc-900 shadow-2xs ring-1 ring-zinc-200/90 dark:bg-zinc-800 dark:text-zinc-100 dark:ring-zinc-700"
                      : "text-zinc-600 hover:bg-zinc-100/80 hover:text-zinc-900 dark:text-zinc-400 dark:hover:bg-zinc-800/60 dark:hover:text-zinc-100"
                  }`}
                >
                  <div className="flex items-center justify-between gap-2">
                    <span
                      className={`font-mono text-xs font-semibold ${
                        active
                          ? "text-blue-600 dark:text-blue-400"
                          : "text-zinc-400 dark:text-zinc-500"
                      }`}
                    >
                      {entry.code}
                    </span>
                    <div className="flex flex-wrap items-center gap-1">
                      {tasks.total > 0 ? (
                        <span className="inline-flex items-center rounded-full bg-zinc-100 px-1.5 py-0.5 font-mono text-[10px] font-medium text-zinc-700 ring-1 ring-zinc-200 dark:bg-zinc-800 dark:text-zinc-300 dark:ring-zinc-700">
                          {tasks.done}/{tasks.total}
                        </span>
                      ) : null}
                      {openDecisions > 0 ? (
                        <span
                          title={`${openDecisions} open decision${openDecisions === 1 ? "" : "s"}`}
                          className="inline-flex items-center rounded-full bg-amber-100 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-amber-800 ring-1 ring-amber-300 dark:bg-amber-950 dark:text-amber-300 dark:ring-amber-800"
                        >
                          ? {openDecisions}
                        </span>
                      ) : null}
                      {entryComments > 0 ? (
                        <span
                          className={`inline-flex items-center gap-1 rounded-full px-1.5 py-0.5 font-mono text-[11px] font-semibold ring-1 ${
                            unanswered > 0
                              ? "bg-blue-600 text-white ring-blue-600"
                              : "bg-blue-50 text-blue-700 ring-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:ring-blue-800"
                          }`}
                        >
                          <MessageSquare className="h-2.5 w-2.5" />
                          {entryComments}
                        </span>
                      ) : null}
                      <StatusBadge status={entry.status} />
                    </div>
                  </div>
                  <div className="mt-1 text-xs leading-snug font-medium text-zinc-800 dark:text-zinc-200">
                    {entry.title}
                  </div>
                </button>
              </li>
            );
          })}
        </ul>
      </nav>
    </aside>
  );
}

function MobileTopBar({
  entryList,
  selectedId,
  currentEntry,
  threads,
  onOpenMenu,
  onSelect,
}) {
  const openThreadsCount = computeOpenThreadsCount(entryList, threads);
  const discussionsActive = selectedId === "__discussions__";
  const idx = (entryList || []).findIndex(
    (item) => item.id === (currentEntry ? currentEntry.id : selectedId),
  );
  const canPrev = idx > 0;
  const canNext = idx !== -1 && idx < (entryList || []).length - 1;

  return (
    <div className="flex shrink-0 items-center justify-between gap-2 border-b border-zinc-200 bg-zinc-50/90 px-3 py-2 font-sans md:hidden dark:border-zinc-800 dark:bg-zinc-900">
      <button
        type="button"
        onClick={onOpenMenu}
        className="flex min-w-0 flex-1 cursor-pointer items-center gap-2 rounded-lg border border-zinc-200 bg-white px-2.5 py-1.5 text-left shadow-2xs dark:border-zinc-700 dark:bg-zinc-800"
      >
        <Menu className="h-4 w-4 shrink-0 text-zinc-600 dark:text-zinc-300" />
        {discussionsActive ? (
          <span className="truncate text-xs font-semibold text-zinc-900 dark:text-zinc-100">
            Open Discussions
          </span>
        ) : currentEntry ? (
          <div className="flex min-w-0 items-center gap-1.5">
            {!isOverviewEntry(currentEntry) && currentEntry.code ? (
              <span className="shrink-0 font-mono text-xs font-semibold text-blue-600 dark:text-blue-400">
                {currentEntry.code}
              </span>
            ) : null}
            <span className="truncate text-xs font-semibold text-zinc-900 dark:text-zinc-100">
              {currentEntry.title}
            </span>
          </div>
        ) : (
          <span className="truncate text-xs font-semibold text-zinc-900 dark:text-zinc-100">
            Sections
          </span>
        )}
      </button>

      <div className="flex shrink-0 items-center gap-1">
        <button
          type="button"
          disabled={!canPrev}
          onClick={() => {
            if (canPrev) onSelect(entryList[idx - 1].id);
          }}
          aria-label="Previous section"
          className="inline-flex h-7 w-7 cursor-pointer items-center justify-center rounded-md border border-zinc-200 bg-white text-zinc-700 disabled:cursor-default disabled:opacity-40 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
        >
          <ChevronLeft className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          disabled={!canNext}
          onClick={() => {
            if (canNext) onSelect(entryList[idx + 1].id);
          }}
          aria-label="Next section"
          className="inline-flex h-7 w-7 cursor-pointer items-center justify-center rounded-md border border-zinc-200 bg-white text-zinc-700 disabled:cursor-default disabled:opacity-40 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
        >
          <ChevronRight className="h-3.5 w-3.5" />
        </button>
        <button
          type="button"
          onClick={() => onSelect("__discussions__")}
          className={`inline-flex cursor-pointer items-center gap-1.5 rounded-lg border px-2.5 py-1.5 text-xs font-semibold ${
            discussionsActive
              ? "border-blue-600 bg-blue-600 text-white"
              : "border-zinc-200 bg-white text-zinc-700 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
          }`}
        >
          <MessageSquare
            className={`h-3.5 w-3.5 ${
              discussionsActive
                ? "text-white"
                : "text-blue-600 dark:text-blue-400"
            }`}
          />
          <span className="font-mono text-[11px]">{openThreadsCount}</span>
        </button>
      </div>
    </div>
  );
}

function countDiffBodyLines(body) {
  const lines = body.split("\n");
  let added = 0;
  let removed = 0;
  for (const l of lines) {
    if (l.startsWith("+") && !l.startsWith("+++")) added++;
    else if (l.startsWith("-") && !l.startsWith("---")) removed++;
  }
  return { added, removed, lineCount: lines.length };
}

function splitUnifiedDiffByFile(rawDiff, defaultFile = "patch") {
  const text = Array.isArray(rawDiff)
    ? rawDiff.join("\n").trim()
    : String(rawDiff || "").trim();
  if (!text) return [];
  const chunks = text.split(/^diff --git /m).filter(Boolean);
  if (chunks.length === 1 && !text.startsWith("diff --git ")) {
    const counts = countDiffBodyLines(text);
    return [{ file: defaultFile || "patch", ...counts, content: text }];
  }
  return chunks.map((chunk) => {
    const firstLineEnd = chunk.indexOf("\n");
    const firstLine =
      firstLineEnd === -1 ? chunk : chunk.slice(0, firstLineEnd);
    const match = / b\/(.+)$/.exec(firstLine.trim());
    const file = match ? match[1] : firstLine.trim();
    const body = firstLineEnd === -1 ? "" : chunk.slice(firstLineEnd + 1);
    const counts = countDiffBodyLines(body);
    return {
      file,
      ...counts,
      content: body,
    };
  });
}

function ThreadReplyBox({
  draftKey,
  onSubmit,
  placeholder = "Reply to thread...",
}) {
  const [draft, setDraft] = useDraft(draftKey);

  const submit = () => {
    const trimmed = draft.trim();
    if (!trimmed) return;
    onSubmit(trimmed);
    setDraft("");
  };

  return (
    <div className="flex gap-2 pt-1 font-sans">
      <input
        type="text"
        value={draft}
        onChange={(e) => setDraft(e.target.value)}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            submit();
          }
        }}
        placeholder={placeholder}
        className="flex-1 rounded-md border border-zinc-200 bg-white px-3 py-1.5 text-sm text-zinc-900 focus:border-blue-600 focus:outline-none dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100"
      />
      <button
        type="button"
        onClick={submit}
        className="inline-flex cursor-pointer items-center gap-1.5 rounded-md bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700"
      >
        <Send className="h-3 w-3" />
        Reply
      </button>
    </div>
  );
}

function InlineThreadPanel({
  entryId,
  itemId,
  itemLabel,
  combined,
  composerOpen,
  onCloseComposer,
  onAddComment,
}) {
  const [draft, setDraft] = useDraft(`new::${itemId}`);

  const submit = () => {
    const trimmed = draft.trim();
    if (!trimmed) return;
    onAddComment({
      entryId,
      itemId,
      blockHeading: itemLabel,
      text: trimmed,
    });
    setDraft("");
    if (onCloseComposer) onCloseComposer();
  };

  return (
    <>
      {combined.length > 0 ? (
        <div className="mt-3 w-full space-y-2 border-l-2 border-blue-500 pl-3.5 font-sans">
          {combined.map((item, idx) => {
            const isAgent = isAgentMessage(item);
            const author = resolveAuthorName(item);
            return (
              <div
                key={item.id || idx}
                className={`w-full rounded-lg border px-3.5 py-2.5 text-sm ${
                  isAgent
                    ? "border-blue-200/80 bg-blue-50/50 text-zinc-900 dark:border-blue-900/70 dark:bg-blue-950/40 dark:text-zinc-100"
                    : "border-zinc-200 bg-white text-zinc-900 dark:border-zinc-700 dark:bg-zinc-900 dark:text-zinc-100"
                }`}
              >
                <div className="mb-1 flex items-center justify-between gap-2 text-xs">
                  <span
                    className={`font-semibold ${
                      isAgent
                        ? "text-blue-700 dark:text-blue-400"
                        : "text-zinc-900 dark:text-zinc-100"
                    }`}
                  >
                    {author}
                  </span>
                  <span className="font-mono text-[11px] text-zinc-400 dark:text-zinc-500">
                    {formatShortTime(item.createdAt)}
                  </span>
                </div>
                <div className="text-sm leading-6">
                  <MarkdownWithTables>
                    {String(item.text || "")}
                  </MarkdownWithTables>
                </div>
              </div>
            );
          })}

          <ThreadReplyBox
            draftKey={`reply::${itemId}`}
            onSubmit={(trimmed) => {
              onAddComment({
                entryId,
                itemId,
                blockHeading: itemLabel,
                text: trimmed,
              });
            }}
          />
        </div>
      ) : null}

      {composerOpen && combined.length === 0 ? (
        <div className="mt-3 w-full rounded-lg border border-zinc-200 bg-white p-3 font-sans shadow-xs dark:border-zinc-700 dark:bg-zinc-900">
          <div className="mb-1.5 flex items-center justify-between gap-2 text-xs text-zinc-500 dark:text-zinc-400">
            <span className="truncate font-medium">
              Comment on{" "}
              <code className="font-mono text-zinc-700 dark:text-zinc-300">
                {itemLabel}
              </code>
            </span>
            <button
              type="button"
              onClick={() => {
                if (onCloseComposer) onCloseComposer();
              }}
              className="shrink-0 cursor-pointer text-zinc-500 hover:text-zinc-900 dark:text-zinc-400 dark:hover:text-zinc-100"
            >
              Cancel
            </button>
          </div>
          <textarea
            value={draft}
            onChange={(e) => setDraft(e.target.value)}
            onKeyDown={(e) => {
              if ((e.metaKey || e.ctrlKey) && e.key === "Enter") {
                e.preventDefault();
                submit();
              } else if (e.key === "Escape" && onCloseComposer) {
                onCloseComposer();
              }
            }}
            placeholder="Write a comment or question for the agent..."
            rows={2}
            autoFocus
            className="w-full rounded-md border border-zinc-300 bg-white px-3 py-2 text-sm text-zinc-900 focus:border-blue-600 focus:outline-none dark:border-zinc-700 dark:bg-zinc-950 dark:text-zinc-100"
          />
          <div className="mt-2 flex justify-end">
            <button
              type="button"
              onClick={submit}
              className="inline-flex cursor-pointer items-center gap-1.5 rounded-md bg-blue-600 px-3 py-1.5 text-xs font-medium text-white hover:bg-blue-700"
            >
              <Send className="h-3 w-3" />
              Post comment
            </button>
          </div>
        </div>
      ) : null}
    </>
  );
}

function parseDiffLinesWithNumbers(rawDiff) {
  const lines = String(rawDiff || "").split("\n");
  let oldNum = null;
  let newNum = null;
  return lines.map((line, idx) => {
    const hunkMatch = /^@@ -(\d+)(?:,\d+)? \+(\d+)(?:,\d+)? @@/.exec(line);
    if (hunkMatch) {
      oldNum = Number.parseInt(hunkMatch[1], 10);
      newNum = Number.parseInt(hunkMatch[2], 10);
      return { line, idx, kind: "hunk", lineLabel: `L${idx + 1}` };
    }
    if (
      line.startsWith("diff --git ") ||
      line.startsWith("+++") ||
      line.startsWith("---") ||
      line.startsWith("index ") ||
      line.startsWith("new file mode ") ||
      line.startsWith("deleted file mode ") ||
      line.startsWith("similarity index ") ||
      line.startsWith("rename from ") ||
      line.startsWith("rename to ")
    ) {
      return { line, idx, kind: "meta", lineLabel: `L${idx + 1}` };
    }
    if (line.startsWith("+")) {
      const n = newNum !== null ? newNum++ : idx + 1;
      return {
        line,
        idx,
        kind: "add",
        numDisplay: String(n),
        lineLabel: `+${n}`,
      };
    }
    if (line.startsWith("-")) {
      const o = oldNum !== null ? oldNum++ : idx + 1;
      return {
        line,
        idx,
        kind: "del",
        numDisplay: String(o),
        lineLabel: `-${o}`,
      };
    }
    const cNum = newNum !== null ? newNum++ : idx + 1;
    if (oldNum !== null) oldNum++;
    return {
      line,
      idx,
      kind: "ctx",
      numDisplay: String(cNum),
      lineLabel: `L${cNum}`,
    };
  });
}

function DiffLinesView({
  diff,
  entryId,
  diffBlockId,
  fileName,
  threads,
  onAddComment,
  onlyCommented = false,
  onSelectEntry = null,
}) {
  const [openLineId, setOpenLineId] = useState(null);
  const parsed = parseDiffLinesWithNumbers(diff);
  const canCommentLines = Boolean(entryId && diffBlockId && onAddComment);
  const safeFile = fileName || "patch";

  const visibleIndices = new Set();
  if (onlyCommented && canCommentLines) {
    parsed.forEach((row) => {
      const lineItemId = `${diffBlockId}::line::${safeFile}::L${row.idx + 1}`;
      if (itemHasComments(lineItemId, threads)) {
        for (
          let k = Math.max(0, row.idx - 3);
          k <= Math.min(parsed.length - 1, row.idx + 2);
          k++
        ) {
          visibleIndices.add(k);
        }
      }
    });
  }

  if (onlyCommented && canCommentLines && visibleIndices.size === 0) {
    return null;
  }

  let prevVisibleIdx = null;

  return (
    <div className="overflow-x-auto bg-white py-2 font-mono text-xs leading-5 break-all whitespace-pre-wrap dark:bg-zinc-950">
      {parsed.map((row) => {
        if (onlyCommented && canCommentLines && !visibleIndices.has(row.idx)) {
          return null;
        }
        const showGap =
          onlyCommented &&
          prevVisibleIdx !== null &&
          row.idx > prevVisibleIdx + 1;
        prevVisibleIdx = row.idx;

        const { line, idx, kind, numDisplay, lineLabel } = row;
        const lineItemId = `${diffBlockId || "diff"}::line::${safeFile}::L${idx + 1}`;
        const snippet = line.trim().slice(0, 60);
        const itemLabel = `${safeFile}:${lineLabel}${snippet ? ` (${snippet})` : ""}`;
        const combined = canCommentLines
          ? getThreadList(threads, lineItemId)
          : [];
        const isComposerOpen = openLineId === lineItemId;

        let lineRow = null;
        if (kind === "meta") {
          lineRow = (
            <div className="px-3.5 font-semibold text-zinc-400 dark:text-zinc-500">
              {line}
            </div>
          );
        } else if (kind === "hunk") {
          lineRow = (
            <div className="my-0.5 bg-sky-50/90 px-3.5 py-0.5 text-sky-800 dark:bg-sky-950/50 dark:text-sky-300">
              {line}
            </div>
          );
        } else {
          const rest = line.slice(1);
          const rowClass =
            kind === "add"
              ? "border-l-2 border-emerald-500 bg-emerald-50/70 text-zinc-900 dark:bg-emerald-950/35 dark:text-zinc-100"
              : kind === "del"
                ? "border-l-2 border-rose-500 bg-rose-50/70 text-zinc-900 dark:bg-rose-950/35 dark:text-zinc-100"
                : "text-zinc-700 dark:text-zinc-300";
          const sign = kind === "add" ? "+" : kind === "del" ? "-" : " ";
          const signClass =
            kind === "add"
              ? "font-bold text-emerald-600 dark:text-emerald-400"
              : kind === "del"
                ? "font-bold text-rose-600 dark:text-rose-400"
                : "text-zinc-300 dark:text-zinc-600";

          lineRow = (
            <div
              className={`group/line flex items-start px-2 py-0.5 hover:bg-blue-50/40 dark:hover:bg-blue-950/30 ${rowClass}`}
            >
              {canCommentLines ? (
                onlyCommented && onSelectEntry && combined.length > 0 ? (
                  <button
                    type="button"
                    onClick={() => onSelectEntry(entryId, lineItemId)}
                    title="Jump to this line in section"
                    className="mr-1.5 inline-flex shrink-0 cursor-pointer items-center gap-0.5 rounded border border-zinc-200 bg-white px-1.5 py-0.5 font-sans text-[10px] font-medium text-blue-600 hover:bg-blue-50 dark:border-zinc-700 dark:bg-zinc-900 dark:text-blue-400"
                  >
                    <span>Jump</span>
                    <ArrowUpRight className="h-2.5 w-2.5" />
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() =>
                      setOpenLineId((prev) =>
                        prev === lineItemId ? null : lineItemId,
                      )
                    }
                    title={`Comment on ${safeFile}:${lineLabel}`}
                    className={`mr-0.5 inline-flex h-4 w-3.5 shrink-0 cursor-pointer items-center justify-center rounded font-sans text-[11px] leading-none transition-colors select-none ${
                      combined.length > 0 || isComposerOpen
                        ? "bg-blue-600 font-semibold text-white opacity-100"
                        : "text-zinc-400 opacity-40 group-hover/line:opacity-100 hover:text-blue-600 dark:text-zinc-500 dark:hover:text-blue-400"
                    }`}
                  >
                    {combined.length > 0 ? combined.length : "+"}
                  </button>
                )
              ) : null}
              <span className="w-8 shrink-0 pr-1.5 text-right text-[10px] text-zinc-400 select-none dark:text-zinc-500">
                {numDisplay || ""}
              </span>
              <span className={`w-4 shrink-0 select-none ${signClass}`}>
                {sign}
              </span>
              <span className="min-w-0 flex-1">
                <HighlightedCodeLine text={rest} />
              </span>
            </div>
          );
        }

        return (
          <div key={idx} id={lineItemId}>
            {showGap ? (
              <div className="border-y border-dashed border-zinc-200 bg-zinc-50 px-3.5 py-0.5 font-sans text-[11px] text-zinc-400 select-none dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-500">
                ···
              </div>
            ) : null}
            {lineRow}
            {canCommentLines && (combined.length > 0 || isComposerOpen) ? (
              <div className="border-y border-zinc-200 bg-zinc-50/70 px-4 py-3 whitespace-normal dark:border-zinc-800 dark:bg-zinc-900/70">
                <InlineThreadPanel
                  entryId={entryId}
                  itemId={lineItemId}
                  itemLabel={itemLabel}
                  combined={combined}
                  composerOpen={isComposerOpen}
                  onCloseComposer={() => setOpenLineId(null)}
                  onAddComment={onAddComment}
                />
              </div>
            ) : null}
          </div>
        );
      })}
    </div>
  );
}

function FileDiffAccordion({
  fileDiff,
  defaultOpen,
  persistedOpen,
  onToggleOpen,
  entryId,
  diffBlockId,
  includeRootId = false,
  threads,
  onAddComment,
  onlyCommented = false,
  onSelectEntry = null,
}) {
  const [fileComposerOpen, setFileComposerOpen] = useState(false);

  const open = onlyCommented
    ? true
    : typeof persistedOpen === "boolean"
      ? persistedOpen
      : defaultOpen;

  const toggle = () => {
    if (onToggleOpen) onToggleOpen(!open);
  };

  const fileItemId = `${diffBlockId || "diff"}::file::${fileDiff.file}`;
  const fileMessages = entryId ? getThreadList(threads, fileItemId) : [];
  const rootMessages =
    entryId && includeRootId && diffBlockId
      ? getThreadList(threads, diffBlockId)
      : [];
  const fileCombined = [...fileMessages, ...rootMessages].sort((a, b) =>
    String((a && a.createdAt) || "").localeCompare(
      String((b && b.createdAt) || ""),
    ),
  );
  const replyAnchorId =
    rootMessages.length > 0 && fileMessages.length === 0
      ? diffBlockId
      : fileItemId;

  return (
    <div
      id={fileItemId}
      className="overflow-hidden rounded-lg border border-zinc-200 bg-white dark:border-zinc-800 dark:bg-zinc-900"
    >
      <div
        className={`flex w-full items-center justify-between gap-2 bg-zinc-50 px-3.5 py-2 font-mono text-xs text-zinc-800 dark:bg-zinc-900 dark:text-zinc-200 ${
          open ||
          fileDiff.description ||
          fileCombined.length > 0 ||
          fileComposerOpen
            ? "border-b border-zinc-200 dark:border-zinc-800"
            : ""
        }`}
      >
        <button
          type="button"
          onClick={toggle}
          className="flex min-w-0 flex-1 cursor-pointer items-center gap-2 text-left hover:text-zinc-950 dark:hover:text-white"
        >
          {open ? (
            <ChevronDown className="h-3.5 w-3.5 shrink-0 text-zinc-500 dark:text-zinc-400" />
          ) : (
            <ChevronRight className="h-3.5 w-3.5 shrink-0 text-zinc-500 dark:text-zinc-400" />
          )}
          <FileCode2 className="h-3.5 w-3.5 shrink-0 text-zinc-500 dark:text-zinc-400" />
          <span className="truncate font-medium">{fileDiff.file}</span>
        </button>

        <div className="flex shrink-0 items-center gap-2 font-mono text-[11px]">
          {typeof fileDiff.added === "number" ? (
            <span className="font-semibold text-emerald-600 dark:text-emerald-400">
              +{fileDiff.added}
            </span>
          ) : null}
          {typeof fileDiff.removed === "number" ? (
            <span className="font-semibold text-rose-600 dark:text-rose-400">
              -{fileDiff.removed}
            </span>
          ) : null}
          {entryId && onAddComment ? (
            onlyCommented && onSelectEntry ? (
              <button
                type="button"
                onClick={() => onSelectEntry(entryId, fileItemId)}
                className="inline-flex cursor-pointer items-center gap-1 rounded border border-zinc-200 bg-white px-2 py-0.5 font-sans text-[11px] font-medium text-blue-600 hover:bg-blue-50 dark:border-zinc-700 dark:bg-zinc-800 dark:text-blue-400"
              >
                <span>Jump to file</span>
                <ArrowUpRight className="h-3 w-3" />
              </button>
            ) : (
              <button
                type="button"
                onClick={() => setFileComposerOpen((v) => !v)}
                title={`Comment on ${fileDiff.file}`}
                className={`inline-flex cursor-pointer items-center gap-1 rounded border px-2 py-0.5 font-sans text-[11px] font-medium ${
                  fileCombined.length > 0 || fileComposerOpen
                    ? "border-blue-200 bg-blue-50 text-blue-700 dark:border-blue-800 dark:bg-blue-950 dark:text-blue-300"
                    : "border-zinc-200 bg-white text-zinc-600 hover:border-zinc-400 hover:text-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
                }`}
              >
                <MessageSquare className="h-3 w-3 text-blue-600 dark:text-blue-400" />
                <span>
                  {fileCombined.length > 0 ? fileCombined.length : "Comment"}
                </span>
              </button>
            )
          ) : null}
        </div>
      </div>

      {fileDiff.description ? (
        <div
          className={`bg-zinc-50/40 px-3.5 py-2 font-sans text-xs leading-5 text-zinc-600 dark:bg-zinc-900/40 dark:text-zinc-400 ${
            open || fileCombined.length > 0 || fileComposerOpen
              ? "border-b border-zinc-200/80 dark:border-zinc-800"
              : ""
          }`}
        >
          <ReactMarkdown components={inlineMarkdownComponents}>
            {String(fileDiff.description)}
          </ReactMarkdown>
        </div>
      ) : null}

      {fileCombined.length > 0 || fileComposerOpen ? (
        <div className="border-b border-zinc-200 bg-zinc-50/70 px-4 py-3 dark:border-zinc-800 dark:bg-zinc-900/70">
          <InlineThreadPanel
            entryId={entryId}
            itemId={replyAnchorId}
            itemLabel={fileDiff.file}
            combined={fileCombined}
            composerOpen={fileComposerOpen}
            onCloseComposer={() => setFileComposerOpen(false)}
            onAddComment={onAddComment}
          />
        </div>
      ) : null}

      {open ? (
        <DiffLinesView
          diff={fileDiff.content}
          entryId={entryId}
          diffBlockId={diffBlockId}
          fileName={fileDiff.file}
          threads={threads}
          onAddComment={onAddComment}
          onlyCommented={onlyCommented}
          onSelectEntry={onSelectEntry}
        />
      ) : null}
    </div>
  );
}

function matchDiffFileMeta(fileName, filesMeta) {
  if (!Array.isArray(filesMeta) || !fileName) return null;
  const idx = filesMeta.findIndex(
    (m) =>
      m &&
      m.file &&
      (m.file === fileName ||
        fileName.endsWith(`/${m.file}`) ||
        m.file.endsWith(`/${fileName}`)),
  );
  return idx >= 0 ? { meta: filesMeta[idx], order: idx } : null;
}

function UnifiedDiffSlip({
  file,
  files,
  diff,
  diffKey,
  entryId,
  diffBlockId,
  threads,
  view,
  onDiffFilesSet,
  onAddComment,
  onlyCommented = false,
  onSelectEntry = null,
}) {
  const raw =
    (diffKey && DIFFS[diffKey]) ||
    (diffBlockId && DIFFS[diffBlockId]) ||
    diff ||
    "";

  const rawFileDiffs = splitUnifiedDiffByFile(raw, file || "patch");
  const allFileDiffs = rawFileDiffs
    .map((fd, origIdx) => {
      const matched = matchDiffFileMeta(fd.file, files);
      return {
        ...fd,
        description:
          (matched && matched.meta.description) || fd.description || "",
        open:
          matched && typeof matched.meta.open === "boolean"
            ? matched.meta.open
            : undefined,
        sortOrder: matched ? matched.order : 1000 + origIdx,
      };
    })
    .sort((a, b) => a.sortOrder - b.sortOrder);

  const fileDiffs =
    onlyCommented && entryId && diffBlockId
      ? allFileDiffs.filter(
          (fd, idx) =>
            (idx === 0 && itemHasComments(diffBlockId, threads)) ||
            itemHasComments(`${diffBlockId}::file::${fd.file}`, threads) ||
            itemHasPrefixComments(
              `${diffBlockId}::line::${fd.file}::`,
              threads,
            ),
        )
      : allFileDiffs;

  if (fileDiffs.length === 0) return null;

  const diffOpenMap = (view && view.diffOpen) || {};
  const allFileKeys = fileDiffs.map((fd) => `${diffBlockId}::${fd.file}`);
  const totalAdded = fileDiffs.reduce((s, fd) => s + (fd.added || 0), 0);
  const totalRemoved = fileDiffs.reduce((s, fd) => s + (fd.removed || 0), 0);

  return (
    <div className="space-y-2.5">
      {fileDiffs.length > 1 ? (
        <div className="flex flex-wrap items-center justify-between gap-2 text-xs text-zinc-500 dark:text-zinc-400">
          <div>
            Showing{" "}
            <strong className="text-zinc-800 dark:text-zinc-200">
              {fileDiffs.length}
            </strong>{" "}
            modified files (
            <span className="font-mono font-semibold text-emerald-600 dark:text-emerald-400">
              +{totalAdded}
            </span>{" "}
            /{" "}
            <span className="font-mono font-semibold text-rose-600 dark:text-rose-400">
              -{totalRemoved}
            </span>
            ) · ordered by importance · click any file header or line{" "}
            <code className="font-mono">+</code> to comment:
          </div>
          {onDiffFilesSet ? (
            <div className="flex items-center gap-1.5">
              <button
                type="button"
                onClick={() => onDiffFilesSet(allFileKeys, true)}
                className="cursor-pointer rounded border border-zinc-200 bg-white px-2 py-0.5 text-[11px] font-medium text-zinc-700 hover:bg-zinc-50 hover:text-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
              >
                Expand all
              </button>
              <button
                type="button"
                onClick={() => onDiffFilesSet(allFileKeys, false)}
                className="cursor-pointer rounded border border-zinc-200 bg-white px-2 py-0.5 text-[11px] font-medium text-zinc-700 hover:bg-zinc-50 hover:text-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
              >
                Collapse all
              </button>
            </div>
          ) : null}
        </div>
      ) : null}

      {fileDiffs.map((fd, idx) => {
        const fileKey = `${diffBlockId}::${fd.file}`;
        const defaultOpen =
          typeof fd.open === "boolean"
            ? fd.open
            : fileDiffs.length === 1 || idx < 2;
        return (
          <FileDiffAccordion
            key={fd.file + idx}
            fileDiff={fd}
            defaultOpen={defaultOpen}
            persistedOpen={diffOpenMap[fileKey]}
            onToggleOpen={
              onDiffFilesSet ? (next) => onDiffFilesSet([fileKey], next) : null
            }
            entryId={entryId}
            diffBlockId={diffBlockId}
            includeRootId={allFileDiffs.length <= 1 || fd === allFileDiffs[0]}
            threads={threads}
            onAddComment={onAddComment}
            onlyCommented={onlyCommented}
            onSelectEntry={onSelectEntry}
          />
        );
      })}
    </div>
  );
}

function PrePostSlip({ preTitle, preBody, postTitle, postBody }) {
  return (
    <div className="grid grid-cols-1 gap-3.5 lg:grid-cols-2">
      <div className="flex flex-col overflow-hidden rounded-lg border border-rose-200 bg-white dark:border-rose-900/70 dark:bg-zinc-900">
        <div className="border-b border-rose-200 bg-rose-50/80 px-3.5 py-2 font-sans text-xs font-semibold text-rose-800 dark:border-rose-900/70 dark:bg-rose-950/60 dark:text-rose-300">
          PRE: {preTitle}
        </div>
        <div className="flex-1 bg-rose-50/15 dark:bg-rose-950/15">
          <SyntaxHighlightedBlock body={preBody} />
        </div>
      </div>

      <div className="flex flex-col overflow-hidden rounded-lg border border-emerald-200 bg-white dark:border-emerald-900/70 dark:bg-zinc-900">
        <div className="border-b border-emerald-200 bg-emerald-50/80 px-3.5 py-2 font-sans text-xs font-semibold text-emerald-800 dark:border-emerald-900/70 dark:bg-emerald-950/60 dark:text-emerald-300">
          POST: {postTitle}
        </div>
        <div className="flex-1 bg-emerald-50/15 dark:bg-emerald-950/15">
          <SyntaxHighlightedBlock body={postBody} />
        </div>
      </div>
    </div>
  );
}

function toneClasses(tone) {
  switch (tone) {
    case "emerald":
      return {
        badge:
          "border-emerald-200 bg-emerald-50 text-emerald-800 dark:border-emerald-800 dark:bg-emerald-950/70 dark:text-emerald-300",
        banner:
          "border-emerald-200 bg-emerald-50/70 text-emerald-900 dark:border-emerald-800 dark:bg-emerald-950/50 dark:text-emerald-200",
        button: "bg-emerald-600 text-white hover:bg-emerald-700",
      };
    case "rose":
      return {
        badge:
          "border-rose-200 bg-rose-50 text-rose-800 dark:border-rose-800 dark:bg-rose-950/70 dark:text-rose-300",
        banner:
          "border-rose-200 bg-rose-50/70 text-rose-900 dark:border-rose-800 dark:bg-rose-950/50 dark:text-rose-200",
        button: "bg-rose-600 text-white hover:bg-rose-700",
      };
    case "amber":
      return {
        badge:
          "border-amber-200 bg-amber-50 text-amber-800 dark:border-amber-800 dark:bg-amber-950/70 dark:text-amber-300",
        banner:
          "border-amber-200 bg-amber-50/70 text-amber-900 dark:border-amber-800 dark:bg-amber-950/50 dark:text-amber-200",
        button: "bg-amber-600 text-white hover:bg-amber-700",
      };
    case "blue":
      return {
        badge:
          "border-blue-200 bg-blue-50 text-blue-800 dark:border-blue-800 dark:bg-blue-950/70 dark:text-blue-300",
        banner:
          "border-blue-200 bg-blue-50/70 text-blue-900 dark:border-blue-800 dark:bg-blue-950/50 dark:text-blue-200",
        button: "bg-blue-600 text-white hover:bg-blue-700",
      };
    default:
      return {
        badge:
          "border-zinc-200 bg-zinc-100 text-zinc-700 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300",
        banner:
          "border-zinc-200 bg-zinc-50 text-zinc-800 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-200",
        button:
          "bg-zinc-900 text-white hover:bg-zinc-800 dark:bg-zinc-100 dark:text-zinc-900",
      };
  }
}

function UiStatesSlip({ item, view, onStageChange }) {
  const stages = Array.isArray(item.stages) ? item.stages : [];
  if (stages.length === 0) return null;

  const savedStageId = view && view.stages ? view.stages[item.id] : null;
  const activeId =
    savedStageId || item.defaultStageId || (stages[0] ? stages[0].id : "");
  const activeStage = stages.find((s) => s.id === activeId) || stages[0];

  return (
    <div className="w-full overflow-hidden rounded-xl border border-zinc-200 bg-zinc-50/50 p-4 dark:border-zinc-800 dark:bg-zinc-900/50">
      <div className="mb-3 flex flex-wrap items-center justify-between gap-2">
        <div className="text-xs font-semibold text-zinc-500 dark:text-zinc-400">
          Interactive UI State Preview (click a state to inspect):
        </div>
        <div className="flex flex-wrap gap-1.5">
          {stages.map((st) => {
            const active = st.id === activeStage.id;
            return (
              <button
                key={st.id}
                type="button"
                onClick={() => onStageChange(item.id, st.id)}
                className={`cursor-pointer rounded-md border px-2.5 py-1 text-xs font-medium transition-all ${
                  active
                    ? "border-blue-600 bg-blue-600 text-white shadow-2xs"
                    : "border-zinc-200 bg-white text-zinc-700 hover:border-zinc-300 hover:text-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
                }`}
              >
                {st.label}
              </button>
            );
          })}
        </div>
      </div>

      {activeStage.note ? (
        <div className="mb-3 rounded-lg border border-blue-200/80 bg-blue-50/60 px-3 py-2 text-xs text-blue-900 dark:border-blue-900/70 dark:bg-blue-950/40 dark:text-blue-200">
          {activeStage.note}
        </div>
      ) : null}

      <div className="space-y-3 rounded-lg border border-zinc-200 bg-white p-4 shadow-2xs dark:border-zinc-800 dark:bg-zinc-900">
        {Array.isArray(activeStage.badges) && activeStage.badges.length > 0 ? (
          <div className="flex flex-wrap items-center gap-2">
            {activeStage.badges.map((b, i) => {
              const tc = toneClasses(b.tone);
              return (
                <span
                  key={i}
                  className={`inline-flex items-center gap-1.5 rounded-full border px-2.5 py-0.5 text-xs font-semibold ${tc.badge}`}
                >
                  {b.tone === "emerald" ? (
                    <CheckCircle2 className="h-3.5 w-3.5" />
                  ) : null}
                  {b.tone === "rose" || b.tone === "amber" ? (
                    <AlertTriangle className="h-3.5 w-3.5" />
                  ) : null}
                  {b.label}
                </span>
              );
            })}
          </div>
        ) : null}

        {activeStage.banner ? (
          <div
            className={`flex flex-wrap items-center justify-between gap-3 rounded-lg border px-3.5 py-2.5 text-xs ${
              toneClasses(activeStage.banner.tone).banner
            }`}
          >
            <div className="flex items-center gap-2 font-medium">
              {activeStage.banner.spinning ? (
                <RefreshCw className="h-3.5 w-3.5 shrink-0 animate-spin" />
              ) : (
                <Sparkles className="h-3.5 w-3.5 shrink-0" />
              )}
              <span>{activeStage.banner.text}</span>
            </div>
            {activeStage.banner.actionLabel ? (
              <span
                className={`inline-flex items-center gap-1.5 rounded-md px-2.5 py-1 text-xs font-semibold ${
                  toneClasses(activeStage.banner.tone).button
                }`}
              >
                {activeStage.banner.actionLabel}
              </span>
            ) : null}
          </div>
        ) : null}

        {activeStage.body ? (
          <div className="text-sm leading-6 text-zinc-700 dark:text-zinc-300">
            <MarkdownWithTables>{String(activeStage.body)}</MarkdownWithTables>
          </div>
        ) : null}

        {activeStage.code ? (
          <SyntaxHighlightedBlock body={activeStage.code} compact />
        ) : null}

        {activeStage.diff ? <DiffLinesView diff={activeStage.diff} /> : null}

        {activeStage.imageSrc ? (
          <img
            src={activeStage.imageSrc}
            alt={activeStage.label}
            className="max-h-96 rounded-lg border border-zinc-200 object-contain dark:border-zinc-800"
          />
        ) : null}
      </div>
    </div>
  );
}

function TasksChecklistCard({
  entryId,
  item,
  threads,
  onTaskStatusChange,
  onAddComment,
  onlyCommented = false,
  onSelectEntry = null,
}) {
  const [openTaskCommentId, setOpenTaskCommentId] = useState(null);
  const rawTasks = Array.isArray(item.items) ? item.items : [];
  const tasks = onlyCommented
    ? rawTasks.filter((t) =>
        itemHasComments(`${item.id}::task::${t.id}`, threads),
      )
    : rawTasks;

  if (tasks.length === 0) return null;

  const doneCount = rawTasks.filter(
    (t) => t && normalizeTaskStatus(t.status) === "done",
  ).length;

  return (
    <div className="w-full overflow-hidden rounded-xl border border-zinc-200 bg-white dark:border-zinc-800 dark:bg-zinc-900">
      <div className="flex flex-wrap items-center justify-between gap-2 border-b border-zinc-200 bg-zinc-50 px-3.5 py-2 text-xs dark:border-zinc-800 dark:bg-zinc-900/80">
        <span className="font-semibold text-zinc-800 dark:text-zinc-200">
          {item.title || "Tasks"}
        </span>
        <span className="font-mono text-[11px] text-zinc-500 dark:text-zinc-400">
          {doneCount}/{rawTasks.length} done
        </span>
      </div>

      <div className="divide-y divide-zinc-200/80 dark:divide-zinc-800">
        {tasks.map((task) => {
          const meta = getTaskStatusMeta(task.status);
          const taskAnchorId = `${item.id}::task::${task.id}`;
          const combined = getThreadList(threads, taskAnchorId);
          const isOpen = openTaskCommentId === taskAnchorId;
          const isDone = normalizeTaskStatus(task.status) === "done";

          return (
            <div key={task.id} id={taskAnchorId} className="px-3.5 py-2.5">
              <div className="flex flex-wrap items-start justify-between gap-2">
                <div className="flex min-w-0 flex-1 items-start gap-2.5">
                  <button
                    type="button"
                    onClick={() =>
                      onTaskStatusChange(
                        entryId,
                        item.id,
                        task.id,
                        nextTaskStatus(task.status),
                      )
                    }
                    title="Click to cycle task status (Todo → Working → Done)"
                    className={`mt-0.5 inline-flex shrink-0 cursor-pointer items-center gap-1.5 rounded-full border px-2 py-0.5 font-sans text-[11px] font-medium transition-colors ${meta.pillClass}`}
                  >
                    <span
                      className={`h-1.5 w-1.5 rounded-full ${meta.dotClass}`}
                    />
                    {meta.label}
                  </button>

                  <div className="min-w-0 flex-1">
                    <div
                      className={`text-sm leading-6 ${
                        isDone
                          ? "text-zinc-400 line-through dark:text-zinc-500"
                          : "text-zinc-800 dark:text-zinc-200"
                      }`}
                    >
                      <ReactMarkdown components={inlineMarkdownComponents}>
                        {String(task.text || "")}
                      </ReactMarkdown>
                    </div>

                    {task.verify || task.owner || task.note ? (
                      <div className="mt-1 flex flex-wrap items-center gap-2 text-xs text-zinc-500 dark:text-zinc-400">
                        {task.owner ? (
                          <span className="rounded bg-zinc-100 px-1.5 py-0.5 font-mono text-[10.5px] text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300">
                            @{task.owner}
                          </span>
                        ) : null}
                        {task.verify ? (
                          <span className="font-mono text-[11px]">
                            verify:{" "}
                            <code className="rounded border border-zinc-200 bg-zinc-50 px-1 py-0.5 text-zinc-700 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300">
                              {task.verify}
                            </code>
                          </span>
                        ) : null}
                        {task.note ? <span>{task.note}</span> : null}
                      </div>
                    ) : null}
                  </div>
                </div>

                {onlyCommented && onSelectEntry ? (
                  <button
                    type="button"
                    onClick={() => onSelectEntry(entryId, taskAnchorId)}
                    className="inline-flex shrink-0 cursor-pointer items-center gap-1 rounded border border-zinc-200 bg-white px-2 py-0.5 text-[11px] font-medium text-blue-600 hover:bg-blue-50 dark:border-zinc-700 dark:bg-zinc-800 dark:text-blue-400"
                  >
                    <span>Jump</span>
                    <ArrowUpRight className="h-3 w-3" />
                  </button>
                ) : (
                  <button
                    type="button"
                    onClick={() =>
                      setOpenTaskCommentId((prev) =>
                        prev === taskAnchorId ? null : taskAnchorId,
                      )
                    }
                    className={`inline-flex shrink-0 cursor-pointer items-center gap-1 rounded border px-2 py-0.5 text-[11px] font-medium ${
                      combined.length > 0 || isOpen
                        ? "border-blue-200 bg-blue-50 text-blue-700 dark:border-blue-800 dark:bg-blue-950 dark:text-blue-300"
                        : "border-zinc-200 bg-white text-zinc-500 hover:text-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-400"
                    }`}
                  >
                    <MessageSquare className="h-3 w-3 text-blue-600 dark:text-blue-400" />
                    <span>{combined.length > 0 ? combined.length : "+"}</span>
                  </button>
                )}
              </div>

              {combined.length > 0 || isOpen ? (
                <InlineThreadPanel
                  entryId={entryId}
                  itemId={taskAnchorId}
                  itemLabel={`Task: ${task.text}`}
                  combined={combined}
                  composerOpen={isOpen}
                  onCloseComposer={() => setOpenTaskCommentId(null)}
                  onAddComment={onAddComment}
                />
              ) : null}
            </div>
          );
        })}
      </div>
    </div>
  );
}

function DecisionCard({ entryId, item, onSelectDecision }) {
  return (
    <div className="w-full rounded-xl border border-zinc-200 bg-zinc-50/50 p-4 dark:border-zinc-800 dark:bg-zinc-900/50">
      <div className="text-sm font-semibold text-zinc-900 dark:text-zinc-100">
        {item.title}
      </div>
      {item.context ? (
        <div className="mt-1.5 text-sm leading-6 text-zinc-600 dark:text-zinc-400">
          <MarkdownWithTables>{String(item.context)}</MarkdownWithTables>
        </div>
      ) : null}

      <div className="mt-3.5 grid grid-cols-1 gap-2">
        {(item.options || []).map((opt) => {
          const selected = item.selected === opt.id;
          return (
            <button
              key={opt.id}
              type="button"
              onClick={() =>
                onSelectDecision(entryId, item.id, selected ? null : opt.id)
              }
              className={`flex w-full cursor-pointer items-start gap-3 rounded-lg border px-3.5 py-2.5 text-left transition-all ${
                selected
                  ? "border-blue-600 bg-blue-50/80 text-zinc-900 ring-1 ring-blue-600 dark:border-blue-500 dark:bg-blue-950/60 dark:text-zinc-100 dark:ring-blue-500"
                  : "border-zinc-200 bg-white text-zinc-800 hover:border-zinc-400 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-200 dark:hover:border-zinc-600"
              }`}
            >
              <span
                className={`mt-1 flex h-4 w-4 shrink-0 items-center justify-center rounded-full border ${
                  selected
                    ? "border-blue-600 bg-blue-600"
                    : "border-zinc-300 bg-white dark:border-zinc-600 dark:bg-zinc-800"
                }`}
              >
                {selected ? (
                  <span className="h-1.5 w-1.5 rounded-full bg-white" />
                ) : null}
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-2 text-xs font-semibold text-zinc-900 dark:text-zinc-100">
                  <span>{opt.label}</span>
                  {selected ? (
                    <span className="rounded bg-blue-600 px-1.5 py-0.5 font-mono text-[10px] font-semibold text-white">
                      Selected
                    </span>
                  ) : null}
                </div>
                {opt.description ? (
                  <div className="mt-0.5 text-xs leading-5 text-zinc-600 dark:text-zinc-400">
                    <ReactMarkdown components={inlineMarkdownComponents}>
                      {String(opt.description)}
                    </ReactMarkdown>
                  </div>
                ) : null}
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
}

function SectionDirectoryBlock({
  entryList,
  onSelectEntry,
  threads,
  onStatusChange,
}) {
  const items = (entryList || []).filter((e) => !isOverviewEntry(e));
  if (items.length === 0) {
    return (
      <div className="rounded-lg border border-zinc-200 bg-zinc-50 px-4 py-6 text-center text-xs text-zinc-500 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-400">
        No sections added yet.
      </div>
    );
  }
  return (
    <div className="divide-y divide-zinc-200 overflow-hidden rounded-lg border border-zinc-200 bg-white dark:divide-zinc-800 dark:border-zinc-800 dark:bg-zinc-900">
      {items.map((item) => {
        const threadCount = entryCommentedItemCount(item, threads);
        const openDecisions = entryOpenDecisionCount(item);
        const tasks = entryTaskCounts(item);
        return (
          <div
            key={item.id}
            className="flex flex-col items-start gap-2.5 px-3.5 py-3.5 transition-colors hover:bg-zinc-50 sm:px-4 dark:hover:bg-zinc-800/40"
          >
            <button
              type="button"
              onClick={() => onSelectEntry(item.id, null)}
              className="flex w-full min-w-0 cursor-pointer items-baseline gap-2.5 text-left"
            >
              <span className="font-mono text-xs font-bold text-blue-600 dark:text-blue-400">
                {item.code}
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex items-center gap-1.5 text-sm font-semibold text-zinc-900 hover:text-blue-600 dark:text-zinc-100 dark:hover:text-blue-400">
                  <span>{item.title}</span>
                  <ArrowUpRight className="h-3.5 w-3.5 shrink-0 text-zinc-400" />
                </div>
                {item.summary ? (
                  <p className="mt-0.5 text-xs text-zinc-500 dark:text-zinc-400">
                    <ReactMarkdown components={inlineMarkdownComponents}>
                      {String(item.summary)}
                    </ReactMarkdown>
                  </p>
                ) : null}
              </div>
            </button>

            <div className="flex flex-wrap items-center gap-2 pl-6">
              <StatusPicker
                status={item.status}
                onChange={(nextStatus) => onStatusChange(item.id, nextStatus)}
              />
              {tasks.total > 0 ? (
                <span className="inline-flex items-center gap-1 rounded-full bg-zinc-100 px-2 py-0.5 font-mono text-[11px] font-medium text-zinc-700 ring-1 ring-zinc-200 dark:bg-zinc-800 dark:text-zinc-300 dark:ring-zinc-700">
                  {tasks.done}/{tasks.total} tasks
                </span>
              ) : null}
              {openDecisions > 0 ? (
                <span className="inline-flex items-center gap-1 rounded-full bg-amber-100 px-2 py-0.5 font-mono text-[11px] font-semibold text-amber-800 ring-1 ring-amber-300 dark:bg-amber-950 dark:text-amber-300 dark:ring-amber-800">
                  ? {openDecisions} to decide
                </span>
              ) : null}
              {threadCount > 0 ? (
                <span className="inline-flex items-center gap-1 rounded-full bg-blue-50 px-2 py-0.5 font-mono text-[11px] font-semibold text-blue-700 ring-1 ring-blue-200 dark:bg-blue-950 dark:text-blue-300 dark:ring-blue-800">
                  <MessageSquare className="h-3 w-3" />
                  {threadCount}
                </span>
              ) : null}
            </div>
          </div>
        );
      })}
    </div>
  );
}

function CommentableItem({
  entryId,
  itemId,
  itemLabel,
  threads,
  onAddComment,
  onlyCommented = false,
  alwaysShowInDiscussions = false,
  onJumpToItem = null,
  children,
}) {
  const [composerOpen, setComposerOpen] = useState(false);
  const combined = getThreadList(threads, itemId);

  if (onlyCommented && combined.length === 0 && !alwaysShowInDiscussions) {
    return null;
  }

  return (
    <div id={itemId} className="group relative py-1">
      <div className="flex items-start justify-between gap-2 sm:gap-4">
        <div className="min-w-0 flex-1">
          {children}
          <InlineThreadPanel
            entryId={entryId}
            itemId={itemId}
            itemLabel={itemLabel}
            combined={combined}
            composerOpen={composerOpen}
            onCloseComposer={() => setComposerOpen(false)}
            onAddComment={onAddComment}
          />
        </div>
        {onlyCommented && onJumpToItem ? (
          <button
            type="button"
            onClick={onJumpToItem}
            title="Jump to this item in its section"
            className="inline-flex shrink-0 cursor-pointer items-center gap-1 rounded-md border border-zinc-200 bg-white px-2 py-1 text-xs font-medium text-blue-600 shadow-2xs hover:border-blue-300 hover:bg-blue-50 dark:border-zinc-700 dark:bg-zinc-800 dark:text-blue-400"
          >
            <span className="hidden sm:inline">Jump to section</span>
            <span className="sm:hidden">Jump</span>
            <ArrowUpRight className="h-3 w-3" />
          </button>
        ) : (
          <button
            type="button"
            onClick={() => setComposerOpen((v) => !v)}
            title="Comment on this item"
            className={`inline-flex shrink-0 cursor-pointer items-center gap-1 rounded-md border px-2 py-1 text-xs font-medium transition-opacity ${
              combined.length > 0 || composerOpen
                ? "border-blue-200 bg-blue-50 text-blue-700 opacity-100 dark:border-blue-800 dark:bg-blue-950 dark:text-blue-300"
                : "border-zinc-200 bg-white text-zinc-600 opacity-75 hover:border-zinc-400 hover:text-zinc-900 md:opacity-0 md:group-hover:opacity-100 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300"
            }`}
          >
            <MessageSquare className="h-3 w-3 text-blue-600 dark:text-blue-400" />
            {combined.length > 0 ? (
              <span>{combined.length}</span>
            ) : (
              <span className="hidden sm:inline">Comment</span>
            )}
          </button>
        )}
      </div>
    </div>
  );
}

function WorkboardItemBody({
  entry,
  block,
  item,
  threads,
  view,
  onAddComment,
  onlyCommented = false,
  onSelectEntry = null,
  onSelectDecision,
  onTaskStatusChange,
  onStageChange,
  onDiffFilesSet,
}) {
  if (item.kind === "demo") {
    const DemoComp = DEMOS[item.demoKey] || DEMOS[item.id];
    if (DemoComp) {
      return (
        <div className="w-full overflow-hidden rounded-xl border border-zinc-200 bg-white p-4 shadow-2xs dark:border-zinc-800 dark:bg-zinc-900">
          {item.title ? (
            <div className="mb-2 text-xs font-semibold text-zinc-500 dark:text-zinc-400">
              {item.title}
            </div>
          ) : null}
          <DemoComp entry={entry} block={block} item={item} />
          {item.caption ? (
            <div className="mt-2.5 border-t border-zinc-100 pt-2 text-xs text-zinc-500 dark:border-zinc-800 dark:text-zinc-400">
              <ReactMarkdown components={inlineMarkdownComponents}>
                {String(item.caption)}
              </ReactMarkdown>
            </div>
          ) : null}
        </div>
      );
    }
  }

  if (item.kind === "tasks") {
    return (
      <TasksChecklistCard
        entryId={entry.id}
        item={item}
        threads={threads}
        onTaskStatusChange={onTaskStatusChange}
        onAddComment={onAddComment}
        onlyCommented={onlyCommented}
        onSelectEntry={onSelectEntry}
      />
    );
  }

  if (item.kind === "decision") {
    return (
      <DecisionCard
        entryId={entry.id}
        item={item}
        onSelectDecision={onSelectDecision}
      />
    );
  }

  if (item.kind === "comparison") {
    return (
      <PrePostSlip
        preTitle={item.preTitle}
        preBody={item.preBody}
        postTitle={item.postTitle}
        postBody={item.postBody}
      />
    );
  }

  if (item.kind === "ui-states") {
    return (
      <UiStatesSlip item={item} view={view} onStageChange={onStageChange} />
    );
  }

  if (item.kind === "diff") {
    return (
      <UnifiedDiffSlip
        file={item.file}
        files={item.files}
        diff={item.diff}
        diffKey={item.diffKey}
        entryId={entry.id}
        diffBlockId={item.id}
        threads={threads}
        view={view}
        onDiffFilesSet={onDiffFilesSet}
        onAddComment={onAddComment}
        onlyCommented={onlyCommented}
        onSelectEntry={onSelectEntry}
      />
    );
  }

  return (
    <div className="w-full">
      <MarkdownWithTables>{String(item.body || "")}</MarkdownWithTables>
    </div>
  );
}

function DossierBlock({
  entry,
  entryList,
  block,
  threads,
  view,
  onAddComment,
  onSelectEntry,
  onStatusChange,
  onSelectDecision,
  onTaskStatusChange,
  onStageChange,
  onDiffFilesSet,
  onlyCommented = false,
}) {
  if (onlyCommented && !blockHasComments(block, threads)) {
    return null;
  }

  const normalizedItems = getBlockItems(block);

  return (
    <section
      id={block.id}
      className="border-b border-zinc-200 pb-7 last:border-b-0 dark:border-zinc-800"
    >
      {block.heading ? (
        <div className="mb-3 flex items-baseline justify-between gap-2">
          <h3 className="text-base font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">
            <ReactMarkdown components={inlineMarkdownComponents}>
              {String(block.heading)}
            </ReactMarkdown>
          </h3>
        </div>
      ) : null}

      <div className="space-y-2">
        {normalizedItems.map((item) => {
          if (item.kind === "directory") {
            if (onlyCommented) return null;
            return (
              <SectionDirectoryBlock
                key={item.id}
                entryList={entryList}
                onSelectEntry={onSelectEntry}
                threads={threads}
                onStatusChange={onStatusChange}
              />
            );
          }

          if (item.kind === "diff") {
            if (onlyCommented && !itemHasAnyComments(item, threads)) {
              return null;
            }
            return (
              <div key={item.id} id={item.id}>
                <WorkboardItemBody
                  entry={entry}
                  block={block}
                  item={item}
                  threads={threads}
                  view={view}
                  onAddComment={onAddComment}
                  onlyCommented={onlyCommented}
                  onSelectEntry={onSelectEntry}
                  onSelectDecision={onSelectDecision}
                  onTaskStatusChange={onTaskStatusChange}
                  onStageChange={onStageChange}
                  onDiffFilesSet={onDiffFilesSet}
                />
              </div>
            );
          }

          return (
            <CommentableItem
              key={item.id}
              entryId={entry.id}
              itemId={item.id}
              itemLabel={item.label || block.heading || item.id}
              threads={threads}
              onAddComment={onAddComment}
              onlyCommented={onlyCommented}
              alwaysShowInDiscussions={
                itemIsOpenDecision(item) ||
                (item.kind === "tasks" && itemHasAnyComments(item, threads))
              }
              onJumpToItem={
                onSelectEntry ? () => onSelectEntry(entry.id, item.id) : null
              }
            >
              <WorkboardItemBody
                entry={entry}
                block={block}
                item={item}
                threads={threads}
                view={view}
                onAddComment={onAddComment}
                onlyCommented={onlyCommented}
                onSelectEntry={onSelectEntry}
                onSelectDecision={onSelectDecision}
                onTaskStatusChange={onTaskStatusChange}
                onStageChange={onStageChange}
                onDiffFilesSet={onDiffFilesSet}
              />
            </CommentableItem>
          );
        })}
      </div>
    </section>
  );
}

function UnanchoredThreadsBlock({
  entry,
  threads,
  onAddComment,
  onSelectEntry,
  onlyCommented = false,
}) {
  const allThreadIds = getEntryThreadBlockIds(entry, threads);
  const orphanedIds = allThreadIds.filter(
    (id) => !isKnownEntryThreadId(entry, id),
  );
  if (orphanedIds.length === 0) return null;

  return (
    <section className="border-b border-zinc-200 pb-7 last:border-b-0 dark:border-zinc-800">
      <div className="mb-3 flex items-baseline justify-between gap-2">
        <h3 className="text-base font-semibold tracking-tight text-zinc-900 dark:text-zinc-100">
          Earlier Threads on Updated Blocks
        </h3>
      </div>
      <div className="space-y-3">
        {orphanedIds.map((itemId) => {
          const msgs = getThreadList(threads, itemId);
          const firstWithHeading = msgs.find((m) => m && m.blockHeading);
          const heading = firstWithHeading
            ? firstWithHeading.blockHeading
            : itemId;
          return (
            <CommentableItem
              key={itemId}
              entryId={entry.id}
              itemId={itemId}
              itemLabel={heading}
              threads={threads}
              onAddComment={onAddComment}
              onlyCommented={onlyCommented}
              onJumpToItem={
                onSelectEntry ? () => onSelectEntry(entry.id, itemId) : null
              }
            >
              <div className="w-full rounded-md border border-amber-200 bg-amber-50/60 px-3 py-2 text-xs text-amber-900 dark:border-amber-900/70 dark:bg-amber-950/40 dark:text-amber-200">
                <span className="font-semibold">
                  Anchored to earlier block:
                </span>{" "}
                <span>{heading}</span>{" "}
                <code className="font-mono text-[11px] text-amber-700 dark:text-amber-300">
                  ({itemId})
                </code>
              </div>
            </CommentableItem>
          );
        })}
      </div>
    </section>
  );
}

function SectionView({
  entry,
  entryList,
  threads,
  view,
  onAddComment,
  onSelectEntry,
  onStatusChange,
  onSelectDecision,
  onTaskStatusChange,
  onStageChange,
  onDiffFilesSet,
  onlyCommented = false,
}) {
  const isOverview = isOverviewEntry(entry);
  const allEntries = entryList || [];
  const currentIdx = allEntries.findIndex((e) => e.id === entry.id);
  const prevEntry = currentIdx > 0 ? allEntries[currentIdx - 1] : null;
  const nextEntry =
    currentIdx >= 0 && currentIdx < allEntries.length - 1
      ? allEntries[currentIdx + 1]
      : null;
  const showStatusPicker =
    !isOverview ||
    entryCommentedItemCount(entry, threads) > 0 ||
    entryOpenDecisionCount(entry) > 0;

  return (
    <article className={onlyCommented ? "space-y-6" : ""}>
      <header className="border-b border-zinc-200 pb-5 dark:border-zinc-800">
        <div className="flex flex-col items-start justify-between gap-3 xl:flex-row xl:items-center">
          {onlyCommented ? (
            <button
              type="button"
              onClick={() => onSelectEntry(entry.id, null)}
              className="inline-flex cursor-pointer items-center gap-2 text-left text-xl font-bold tracking-tight text-zinc-900 hover:text-blue-600 dark:text-zinc-100 dark:hover:text-blue-400"
            >
              {!isOverview && entry.code ? (
                <span className="font-mono text-lg text-blue-600 dark:text-blue-400">
                  {entry.code}
                </span>
              ) : null}
              <span>{entry.title}</span>
              <ArrowUpRight className="h-4 w-4 text-zinc-400" />
            </button>
          ) : (
            <h2 className="text-2xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100">
              {!isOverview && entry.code ? (
                <span className="mr-2.5 font-mono text-xl text-blue-600 dark:text-blue-400">
                  {entry.code}
                </span>
              ) : null}
              {entry.title}
            </h2>
          )}

          {showStatusPicker ? (
            <StatusPicker
              status={entry.status}
              onChange={(nextStatus) => onStatusChange(entry.id, nextStatus)}
            />
          ) : null}
        </div>

        {entry.tldr ? (
          <div className="mt-4">
            <CommentableItem
              entryId={entry.id}
              itemId={`${entry.id}-tldr`}
              itemLabel={`${entry.title} (TL;DR)`}
              threads={threads}
              onAddComment={onAddComment}
              onlyCommented={onlyCommented}
              onJumpToItem={
                onSelectEntry
                  ? () => onSelectEntry(entry.id, `${entry.id}-tldr`)
                  : null
              }
            >
              <div className="w-full text-sm leading-6 text-zinc-700 dark:text-zinc-300">
                <MarkdownWithTables>{String(entry.tldr)}</MarkdownWithTables>
              </div>
            </CommentableItem>
          </div>
        ) : null}
      </header>

      <div className={onlyCommented ? "space-y-7" : "mt-7 space-y-7 pb-16"}>
        {(entry.blocks || []).map((block) => (
          <DossierBlock
            key={block.id}
            entry={entry}
            entryList={entryList}
            block={block}
            threads={threads}
            view={view}
            onAddComment={onAddComment}
            onSelectEntry={onSelectEntry}
            onStatusChange={onStatusChange}
            onSelectDecision={onSelectDecision}
            onTaskStatusChange={onTaskStatusChange}
            onStageChange={onStageChange}
            onDiffFilesSet={onDiffFilesSet}
            onlyCommented={onlyCommented}
          />
        ))}

        <UnanchoredThreadsBlock
          entry={entry}
          threads={threads}
          onAddComment={onAddComment}
          onSelectEntry={onSelectEntry}
          onlyCommented={onlyCommented}
        />

        {!onlyCommented ? (
          <footer className="flex flex-wrap items-center justify-between gap-3 border-t border-zinc-200 pt-5 dark:border-zinc-800">
            <div className="flex flex-wrap items-center gap-2.5">
              {showStatusPicker ? (
                <>
                  <span className="text-xs font-medium text-zinc-500 dark:text-zinc-400">
                    Section status:
                  </span>
                  <StatusPicker
                    status={entry.status}
                    onChange={(nextStatus) =>
                      onStatusChange(entry.id, nextStatus)
                    }
                  />
                </>
              ) : null}
            </div>
            {prevEntry || nextEntry ? (
              <div className="flex flex-wrap items-center gap-2">
                {prevEntry ? (
                  <button
                    type="button"
                    onClick={() => onSelectEntry(prevEntry.id, null)}
                    className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-zinc-200 bg-white px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 hover:text-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300 dark:hover:bg-zinc-700"
                  >
                    <ChevronLeft className="h-3.5 w-3.5 text-zinc-400" />
                    <span>
                      {prevEntry.code
                        ? `${prevEntry.code} ${prevEntry.title}`
                        : prevEntry.title}
                    </span>
                  </button>
                ) : null}
                {nextEntry ? (
                  <button
                    type="button"
                    onClick={() => onSelectEntry(nextEntry.id, null)}
                    className="inline-flex cursor-pointer items-center gap-1.5 rounded-lg border border-zinc-200 bg-white px-3 py-1.5 text-xs font-medium text-zinc-700 hover:bg-zinc-50 hover:text-zinc-900 dark:border-zinc-700 dark:bg-zinc-800 dark:text-zinc-300 dark:hover:bg-zinc-700"
                  >
                    <span>
                      {nextEntry.code
                        ? `${nextEntry.code} ${nextEntry.title}`
                        : nextEntry.title}
                    </span>
                    <ChevronRight className="h-3.5 w-3.5 text-zinc-400" />
                  </button>
                ) : null}
              </div>
            ) : null}
          </footer>
        ) : null}
      </div>
    </article>
  );
}

function OpenDiscussionsView({
  entryList,
  threads,
  view,
  onAddComment,
  onSelectEntry,
  onStatusChange,
  onSelectDecision,
  onTaskStatusChange,
  onStageChange,
  onDiffFilesSet,
}) {
  const allEntries = entryList || [];
  const anyCommented = allEntries.some(
    (entry) =>
      entryCommentedItemCount(entry, threads) > 0 ||
      entryOpenDecisionCount(entry) > 0,
  );
  const openEntries = allEntries.filter(
    (entry) =>
      normalizeStatus(entry.status) !== "reviewed" &&
      (entryCommentedItemCount(entry, threads) > 0 ||
        entryOpenDecisionCount(entry) > 0),
  );

  return (
    <div className="mx-auto max-w-4xl">
      <header className="border-b border-zinc-200 pb-5 dark:border-zinc-800">
        <div>
          <h2 className="text-2xl font-bold tracking-tight text-zinc-900 dark:text-zinc-100">
            Open Discussions
          </h2>
          <p className="mt-1 text-sm text-zinc-500 dark:text-zinc-400">
            Filtered view of all commented blocks and open decisions on sections
            that are{" "}
            <strong className="text-zinc-800 dark:text-zinc-200">
              Planned
            </strong>
            ,{" "}
            <strong className="text-zinc-800 dark:text-zinc-200">
              Working
            </strong>
            , or{" "}
            <strong className="text-zinc-800 dark:text-zinc-200">
              To Review
            </strong>
            .
          </p>
        </div>
      </header>

      <div className="mt-7 space-y-10 pb-16">
        {openEntries.length === 0 ? (
          <div className="w-full rounded-lg border border-zinc-200 bg-zinc-50 p-8 text-center text-sm text-zinc-500 dark:border-zinc-800 dark:bg-zinc-900 dark:text-zinc-400">
            {anyCommented ? (
              <>
                All sections with comments are currently marked{" "}
                <strong className="text-zinc-800 dark:text-zinc-200">
                  Reviewed
                </strong>
                .
              </>
            ) : (
              "No comment threads yet. Hover any paragraph, task, code block, or decision card to start a discussion."
            )}
          </div>
        ) : (
          openEntries.map((entry) => (
            <SectionView
              key={entry.id}
              entry={entry}
              entryList={entryList}
              threads={threads}
              view={view}
              onAddComment={onAddComment}
              onSelectEntry={onSelectEntry}
              onStatusChange={onStatusChange}
              onSelectDecision={onSelectDecision}
              onTaskStatusChange={onTaskStatusChange}
              onStageChange={onStageChange}
              onDiffFilesSet={onDiffFilesSet}
              onlyCommented
            />
          ))
        )}
      </div>
    </div>
  );
}

function EntryDossier({
  mainRef,
  selectedId,
  entry,
  entryList,
  threads,
  view,
  onAddComment,
  onSelectEntry,
  onStatusChange,
  onSelectDecision,
  onTaskStatusChange,
  onStageChange,
  onDiffFilesSet,
}) {
  if (selectedId === "__discussions__") {
    return (
      <main
        ref={mainRef}
        className="flex-1 overflow-y-auto px-4 py-5 font-sans sm:px-6 md:px-10 md:py-8"
      >
        <OpenDiscussionsView
          entryList={entryList}
          threads={threads}
          view={view}
          onAddComment={onAddComment}
          onSelectEntry={onSelectEntry}
          onStatusChange={onStatusChange}
          onSelectDecision={onSelectDecision}
          onTaskStatusChange={onTaskStatusChange}
          onStageChange={onStageChange}
          onDiffFilesSet={onDiffFilesSet}
        />
      </main>
    );
  }

  if (!entry) {
    return (
      <main
        ref={mainRef}
        className="flex-1 overflow-y-auto px-4 py-5 font-mono text-sm text-zinc-500 dark:text-zinc-400"
      >
        Loading workboard entries...
      </main>
    );
  }

  return (
    <main
      ref={mainRef}
      className="flex-1 overflow-y-auto px-4 py-5 font-sans sm:px-6 md:px-10 md:py-8"
    >
      <div className="mx-auto max-w-4xl">
        <SectionView
          entry={entry}
          entryList={entryList}
          threads={threads}
          view={view}
          onAddComment={onAddComment}
          onSelectEntry={onSelectEntry}
          onStatusChange={onStatusChange}
          onSelectDecision={onSelectDecision}
          onTaskStatusChange={onTaskStatusChange}
          onStageChange={onStageChange}
          onDiffFilesSet={onDiffFilesSet}
        />
      </div>
    </main>
  );
}
