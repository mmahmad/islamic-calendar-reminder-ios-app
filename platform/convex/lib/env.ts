export function adminEmails(): Set<string> {
  const raw = process.env.ADMIN_EMAILS ?? "";
  const emails = raw
    .split(",")
    .map((email) => email.trim().toLowerCase())
    .filter((email) => email.length > 0);
  return new Set(emails);
}

export function isAdminEmail(email: string | undefined): boolean {
  if (!email) {
    return false;
  }
  return adminEmails().has(email.toLowerCase());
}
