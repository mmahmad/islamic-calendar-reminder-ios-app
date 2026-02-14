import { FormEvent, useEffect, useMemo, useState } from "react";
import { useConvexAuth, useMutation, useQuery } from "convex/react";
import { useAuthActions } from "@convex-dev/auth/react";
import { api } from "../convex/_generated/api";

type Methodology = "moonsighting" | "calculated" | "hybrid";

export default function App() {
  const { isAuthenticated, isLoading } = useConvexAuth();
  const currentUser = useQuery(api.users.getCurrentUser);
  const ensureCurrentUser = useMutation(api.users.ensureCurrentUser);

  useEffect(() => {
    if (!isAuthenticated || currentUser !== null) {
      return;
    }
    void ensureCurrentUser().catch(() => undefined);
  }, [isAuthenticated, currentUser, ensureCurrentUser]);

  if (isLoading || currentUser === undefined) {
    return (
      <div className="container">
        <div className="card">
          <p className="subtitle">Loading…</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated) {
    return (
      <div className="container">
        <SignInCard />
      </div>
    );
  }

  if (currentUser === null) {
    return (
      <div className="container">
        <div className="card">
          <p className="subtitle">Setting up your profile…</p>
        </div>
      </div>
    );
  }

  if (!currentUser.approved) {
    return (
      <div className="container">
        <PendingApprovalCard email={currentUser.email} />
      </div>
    );
  }

  return (
    <div className="container">
      <AuthorityConsole currentUser={currentUser} />
    </div>
  );
}

function SignInCard() {
  const { signIn } = useAuthActions();
  const [flow, setFlow] = useState<"signIn" | "signUp">("signIn");
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [error, setError] = useState<string | null>(null);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    try {
      await signIn("password", { email, password, flow });
    } catch (err) {
      setError(err instanceof Error ? err.message : "Sign in failed.");
    }
  };

  return (
    <div className="card stack">
      <div>
        <h1 className="title">Authority Platform</h1>
        <p className="subtitle">Sign in to browse authorities or publish as a representative.</p>
      </div>
      <form className="stack" onSubmit={submit}>
        <input
          type="email"
          placeholder="Email"
          value={email}
          onChange={(event) => setEmail(event.target.value)}
          required
        />
        <input
          type="password"
          placeholder="Password"
          value={password}
          onChange={(event) => setPassword(event.target.value)}
          required
        />
        <div className="row wrap">
          <button type="submit">{flow === "signIn" ? "Sign In" : "Sign Up"}</button>
          <button
            type="button"
            className="secondary"
            onClick={() => setFlow(flow === "signIn" ? "signUp" : "signIn")}
          >
            Switch to {flow === "signIn" ? "Sign Up" : "Sign In"}
          </button>
        </div>
        {error && <div className="error">{error}</div>}
      </form>
      <p className="helper">New users require approval before publishing access is enabled.</p>
    </div>
  );
}

function PendingApprovalCard({ email }: { email: string }) {
  const { signOut } = useAuthActions();

  return (
    <div className="card stack">
      <div>
        <h1 className="title">Pending Approval</h1>
        <p className="subtitle">Your account needs approval before platform access is granted.</p>
      </div>
      <div className="row wrap">
        <span className="badge">{email}</span>
        <button className="ghost" onClick={() => void signOut()}>
          Sign out
        </button>
      </div>
    </div>
  );
}

function AuthorityConsole({
  currentUser,
}: {
  currentUser: { email: string; isAdmin: boolean; name: string };
}) {
  const { signOut } = useAuthActions();

  const authorities = useQuery(api.authorities.listAuthorities, { includeInactive: true });
  const subscription = useQuery(api.subscriptions.getMySubscription);
  const pendingUsers = useQuery(currentUser.isAdmin ? api.users.listPendingUsers : "skip");

  const createAuthority = useMutation(api.authorities.createAuthority);
  const upsertMonth = useMutation(api.authorities.upsertAuthorityMonth);
  const publishFullYear = useMutation(api.authorities.publishFullYear);
  const deleteMonth = useMutation(api.authorities.deleteAuthorityMonth);
  const approveUser = useMutation(api.users.approveUser);
  const setSubscription = useMutation(api.subscriptions.setMySubscription);
  const clearSubscription = useMutation(api.subscriptions.clearMySubscription);

  const [selectedAuthoritySlug, setSelectedAuthoritySlug] = useState("");

  const [createSlug, setCreateSlug] = useState("");
  const [createName, setCreateName] = useState("");
  const [createRegionCode, setCreateRegionCode] = useState("US");
  const [createMethodology, setCreateMethodology] = useState<Methodology>("moonsighting");

  const [hijriYear, setHijriYear] = useState("1447");
  const [hijriMonth, setHijriMonth] = useState("1");
  const [gregorianStartDate, setGregorianStartDate] = useState("");

  const [bulkYear, setBulkYear] = useState("1448");
  const [bulkMonthsText, setBulkMonthsText] = useState("1=2026-06-16\n2=2026-07-15");

  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const fallbackAuthoritySlug = authorities?.[0]?.slug ?? "";
  const activeAuthoritySlug =
    selectedAuthoritySlug || subscription?.authority.slug || fallbackAuthoritySlug;

  useEffect(() => {
    if (selectedAuthoritySlug || !fallbackAuthoritySlug) {
      return;
    }
    setSelectedAuthoritySlug(fallbackAuthoritySlug);
  }, [selectedAuthoritySlug, fallbackAuthoritySlug]);

  const authority = useQuery(
    api.authorities.getAuthorityBySlug,
    activeAuthoritySlug ? { slug: activeAuthoritySlug } : "skip",
  );
  const months = useQuery(
    api.authorities.listAuthorityMonths,
    activeAuthoritySlug ? { slug: activeAuthoritySlug } : "skip",
  );

  const sortedMonths = useMemo(() => months ?? [], [months]);

  const handleCreateAuthority = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setStatus(null);

    try {
      const created = await createAuthority({
        slug: createSlug,
        name: createName,
        regionCode: createRegionCode,
        methodology: createMethodology,
      });
      setSelectedAuthoritySlug(created.slug);
      setCreateSlug("");
      setCreateName("");
      setStatus("Authority created.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to create authority.");
    }
  };

  const handlePublishSingleMonth = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setStatus(null);

    if (!activeAuthoritySlug) {
      setError("Select an authority first.");
      return;
    }

    try {
      await upsertMonth({
        slug: activeAuthoritySlug,
        hijriYear: Number(hijriYear),
        hijriMonth: Number(hijriMonth),
        gregorianStartDate,
      });
      setStatus("Saved month start update.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to save month update.");
    }
  };

  const handlePublishFullYear = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setStatus(null);

    if (!activeAuthoritySlug) {
      setError("Select an authority first.");
      return;
    }

    try {
      const monthsPayload = bulkMonthsText
        .split("\n")
        .map((line) => line.trim())
        .filter((line) => line.length > 0)
        .map((line) => {
          const [monthText, dateText] = line.split("=");
          if (!monthText || !dateText) {
            throw new Error(`Invalid line format: ${line}`);
          }
          return {
            hijriMonth: Number(monthText.trim()),
            gregorianStartDate: dateText.trim(),
            status: "projected" as const,
          };
        });

      await publishFullYear({
        slug: activeAuthoritySlug,
        hijriYear: Number(bulkYear),
        months: monthsPayload,
      });
      setStatus("Published full-year projection.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to publish full year.");
    }
  };

  const handleSubscribe = async () => {
    if (!activeAuthoritySlug) {
      return;
    }
    setError(null);
    setStatus(null);

    try {
      await setSubscription({ authoritySlug: activeAuthoritySlug });
      setStatus(`Test subscription set to ${activeAuthoritySlug}.`);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to subscribe.");
    }
  };

  const handleClearSubscription = async () => {
    setError(null);
    setStatus(null);

    try {
      await clearSubscription();
      setStatus("Subscription cleared.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to clear subscription.");
    }
  };

  return (
    <div className="stack">
      <div className="card stack">
        <div className="row wrap" style={{ justifyContent: "space-between" }}>
          <div>
            <h1 className="title">Authority Platform</h1>
            <p className="subtitle">Browse authorities, subscribe, and publish updates.</p>
          </div>
          <div className="row wrap">
            <span className="badge">{currentUser.email}</span>
            <button className="ghost" onClick={() => void signOut()}>
              Sign out
            </button>
          </div>
        </div>
      </div>

      <div className="card stack">
        <h2 className="title">Authority Directory</h2>
        {!authorities || authorities.length === 0 ? (
          <p className="helper">No authorities yet. An admin can create one below.</p>
        ) : (
          <div className="row wrap">
            <select
              value={activeAuthoritySlug}
              onChange={(event) => setSelectedAuthoritySlug(event.target.value)}
            >
              {authorities.map((item) => (
                <option key={item.slug} value={item.slug}>
                  {item.name} ({item.slug})
                </option>
              ))}
            </select>
            {authority && (
              <span className="badge">
                {authority.regionCode} • {authority.methodology}
              </span>
            )}
          </div>
        )}

        <div className="row wrap">
          <button onClick={() => void handleSubscribe()} disabled={!activeAuthoritySlug}>
            Test subscription (debug)
          </button>
          <button className="secondary" onClick={() => void handleClearSubscription()}>
            Clear subscription
          </button>
          {subscription?.authority && (
            <span className="helper">Current: {subscription.authority.name}</span>
          )}
        </div>
      </div>

      {currentUser.isAdmin && (
        <div className="card stack">
          <h2 className="title">Create Authority</h2>
          <form className="stack" onSubmit={handleCreateAuthority}>
            <div className="row wrap">
              <input
                placeholder="Slug (e.g. chc)"
                value={createSlug}
                onChange={(event) => setCreateSlug(event.target.value)}
                required
              />
              <input
                placeholder="Authority name"
                value={createName}
                onChange={(event) => setCreateName(event.target.value)}
                required
              />
            </div>
            <div className="row wrap">
              <input
                placeholder="Region code"
                value={createRegionCode}
                onChange={(event) => setCreateRegionCode(event.target.value.toUpperCase())}
                required
              />
              <select
                value={createMethodology}
                onChange={(event) => setCreateMethodology(event.target.value as Methodology)}
              >
                <option value="moonsighting">Moonsighting</option>
                <option value="calculated">Calculated</option>
                <option value="hybrid">Hybrid</option>
              </select>
              <button type="submit">Create</button>
            </div>
          </form>
        </div>
      )}

      <div className="card stack">
        <h2 className="title">Publish Single Month Start</h2>
        <form className="stack" onSubmit={handlePublishSingleMonth}>
          <div className="row wrap">
            <input
              type="number"
              min="1"
              value={hijriYear}
              onChange={(event) => setHijriYear(event.target.value)}
              placeholder="Hijri year"
              required
            />
            <select value={hijriMonth} onChange={(event) => setHijriMonth(event.target.value)}>
              {Array.from({ length: 12 }).map((_, index) => {
                const month = index + 1;
                return (
                  <option key={month} value={month}>
                    {month}
                  </option>
                );
              })}
            </select>
            <input
              type="date"
              value={gregorianStartDate}
              onChange={(event) => setGregorianStartDate(event.target.value)}
              required
            />
            <button type="submit" disabled={!activeAuthoritySlug}>
              Save
            </button>
          </div>
        </form>
      </div>

      <div className="card stack">
        <h2 className="title">Publish Full-Year Projection</h2>
        <form className="stack" onSubmit={handlePublishFullYear}>
          <div className="row wrap">
            <input
              type="number"
              min="1"
              value={bulkYear}
              onChange={(event) => setBulkYear(event.target.value)}
              placeholder="Hijri year"
              required
            />
            <button type="submit" disabled={!activeAuthoritySlug}>
              Publish
            </button>
          </div>
          <textarea
            value={bulkMonthsText}
            onChange={(event) => setBulkMonthsText(event.target.value)}
            rows={6}
            placeholder="One entry per line: <month>=<YYYY-MM-DD>"
          />
        </form>
      </div>

      <div className="card stack">
        <h2 className="title">Published Months</h2>
        {!activeAuthoritySlug ? (
          <p className="helper">Select an authority first.</p>
        ) : sortedMonths.length === 0 ? (
          <p className="helper">No month starts published yet.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Hijri</th>
                <th>Gregorian start</th>
                <th>Status</th>
                <th>Updated</th>
                <th></th>
              </tr>
            </thead>
            <tbody>
              {sortedMonths.map((entry) => (
                <tr key={entry.id}>
                  <td>
                    {entry.hijriMonth}/{entry.hijriYear}
                  </td>
                  <td>{entry.gregorianStartDate}</td>
                  <td>{entry.status}</td>
                  <td>{new Date(entry.updatedAt).toLocaleDateString()}</td>
                  <td>
                    <button
                      className="ghost"
                      onClick={() => void deleteMonth({ id: entry.id })}
                    >
                      Delete
                    </button>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        )}
      </div>

      {currentUser.isAdmin && (
        <div className="card stack">
          <h2 className="title">Pending Approvals</h2>
          {pendingUsers && pendingUsers.length === 0 && (
            <p className="helper">No pending users.</p>
          )}
          {pendingUsers && pendingUsers.length > 0 && (
            <table className="table">
              <thead>
                <tr>
                  <th>Email</th>
                  <th>Name</th>
                  <th>Requested</th>
                  <th></th>
                </tr>
              </thead>
              <tbody>
                {pendingUsers.map((user) => (
                  <tr key={user.id}>
                    <td>{user.email}</td>
                    <td>{user.name}</td>
                    <td>{new Date(user.createdAt).toLocaleDateString()}</td>
                    <td>
                      <button onClick={() => void approveUser({ userId: user.id })}>
                        Approve
                      </button>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          )}
        </div>
      )}

      {status && <div className="success">{status}</div>}
      {error && <div className="error">{error}</div>}
    </div>
  );
}
