import { FormEvent, useMemo, useState } from "react";
import { useConvexAuth, useMutation, useQuery } from "convex/react";
import { useAuthActions } from "@convex-dev/auth/react";
import { api } from "../convex/_generated/api";

const AUTHORITY_SLUG = "chc";
const AUTHORITY_NAME = "Central Hilal Committee";

export default function App() {
  const { isAuthenticated, isLoading } = useConvexAuth();
  const currentUser = useQuery(api.users.getCurrentUser);

  if (isLoading || currentUser === undefined) {
    return (
      <div className="container">
        <div className="card">
          <p className="subtitle">Loading…</p>
        </div>
      </div>
    );
  }

  if (!isAuthenticated || currentUser === null) {
    return (
      <div className="container">
        <SignInCard />
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
        <h1 className="title">Authority Console</h1>
        <p className="subtitle">Sign in to manage CHC moonsighting updates.</p>
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
      <p className="helper">New users require approval before access is granted.</p>
    </div>
  );
}

function PendingApprovalCard({ email }: { email: string }) {
  const { signOut } = useAuthActions();

  return (
    <div className="card stack">
      <div>
        <h1 className="title">Pending Approval</h1>
        <p className="subtitle">Your account needs approval before you can submit updates.</p>
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
  const authority = useQuery(api.authorities.getAuthorityBySlug, { slug: AUTHORITY_SLUG });
  const months = useQuery(api.authorities.listAuthorityMonths, { slug: AUTHORITY_SLUG });
  const pendingUsers = useQuery(currentUser.isAdmin ? api.users.listPendingUsers : null);

  const createAuthority = useMutation(api.authorities.createAuthority);
  const upsertMonth = useMutation(api.authorities.upsertAuthorityMonth);
  const deleteMonth = useMutation(api.authorities.deleteAuthorityMonth);
  const approveUser = useMutation(api.users.approveUser);

  const [hijriYear, setHijriYear] = useState("1447");
  const [hijriMonth, setHijriMonth] = useState("1");
  const [gregorianStartDate, setGregorianStartDate] = useState("");
  const [status, setStatus] = useState<string | null>(null);
  const [error, setError] = useState<string | null>(null);

  const sortedMonths = useMemo(() => months ?? [], [months]);

  const handleCreateAuthority = async () => {
    setError(null);
    setStatus(null);
    try {
      await createAuthority({ slug: AUTHORITY_SLUG, name: AUTHORITY_NAME });
      setStatus("Authority created.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to create authority.");
    }
  };

  const handleSubmit = async (event: FormEvent) => {
    event.preventDefault();
    setError(null);
    setStatus(null);
    try {
      await upsertMonth({
        slug: AUTHORITY_SLUG,
        hijriYear: Number(hijriYear),
        hijriMonth: Number(hijriMonth),
        gregorianStartDate,
      });
      setStatus("Saved update.");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unable to save update.");
    }
  };

  const handleEdit = (entry: {
    hijriYear: number;
    hijriMonth: number;
    gregorianStartDate: string;
  }) => {
    setHijriYear(String(entry.hijriYear));
    setHijriMonth(String(entry.hijriMonth));
    setGregorianStartDate(entry.gregorianStartDate);
  };

  return (
    <div className="stack">
      <div className="card stack">
        <div className="row wrap" style={{ justifyContent: "space-between" }}>
          <div>
            <h1 className="title">Authority Console</h1>
            <p className="subtitle">Managing: {AUTHORITY_NAME}</p>
          </div>
          <div className="row wrap">
            <span className="badge">{currentUser.email}</span>
            <button className="ghost" onClick={() => void signOut()}>
              Sign out
            </button>
          </div>
        </div>
        {!authority && currentUser.isAdmin && (
          <div className="row wrap">
            <button onClick={handleCreateAuthority}>Create CHC Authority</button>
            <span className="helper">Run once before publishing updates.</span>
          </div>
        )}
        {!authority && !currentUser.isAdmin && (
          <p className="helper">Authority has not been created yet. Ask an admin to create it.</p>
        )}
      </div>

      <div className="card stack">
        <h2 className="title">Publish Month Start</h2>
        <form className="stack" onSubmit={handleSubmit}>
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
            <button type="submit">Save</button>
          </div>
          {status && <div className="success">{status}</div>}
          {error && <div className="error">{error}</div>}
        </form>
      </div>

      <div className="card stack">
        <h2 className="title">Published Months</h2>
        {sortedMonths.length === 0 ? (
          <p className="helper">No month starts published yet.</p>
        ) : (
          <table className="table">
            <thead>
              <tr>
                <th>Hijri</th>
                <th>Gregorian start</th>
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
                  <td>{new Date(entry.updatedAt).toLocaleDateString()}</td>
                  <td className="row wrap">
                    <button className="secondary" onClick={() => handleEdit(entry)}>
                      Edit
                    </button>
                    <button className="ghost" onClick={() => void deleteMonth({ id: entry.id })}>
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
    </div>
  );
}
