import { useState } from "react";
import ActionSheet from "../components/ActionSheet";
import Avatar from "../components/Avatar";
import ConfirmDialog from "../components/ConfirmDialog";
import StaffNotes from "../components/StaffNotes";
import { useToast } from "../components/Toast";
import { useOpenReports, resolveReport, fetchReportPreview } from "../lib/hooks";

const ACTIONS = [
  { value: "no_action", label: "No action / dismiss" },
  { value: "remove_content", label: "Remove content" },
  { value: "warn", label: "Warn" },
  { value: "restrict", label: "Restrict (7 days)" },
  { value: "suspend", label: "Suspend (30 days)" },
  { value: "ban", label: "Ban user", danger: true },
];

const DANGEROUS = new Set(["ban", "suspend", "restrict", "remove_content"]);

function timeAgo(iso) {
  const d = new Date(iso);
  return d.toLocaleString(undefined, {
    month: "short",
    day: "numeric",
    hour: "numeric",
    minute: "2-digit",
  });
}

export default function Reports() {
  const { reports, loading, error, reload } = useOpenReports();
  const [sheetFor, setSheetFor] = useState(null);
  const [confirmFor, setConfirmFor] = useState(null);
  const [preview, setPreview] = useState(null); // full RPC payload
  const [previewLoading, setPreviewLoading] = useState(false);
  const { showToast, ToastEl } = useToast();

  const openPreview = async (report) => {
    setPreview({ report });
    setPreviewLoading(true);
    try {
      const data = await fetchReportPreview(report.id);
      setPreview(data);
    } catch (e) {
      showToast(e.message || "Could not load content preview", "error");
      // Keep basic report info visible even if preview RPC fails
      setPreview({
        report: {
          id: report.id,
          target_type: report.target_type,
          target_id: report.target_id,
          reason: report.reason,
          details: report.details,
          created_at: report.created_at,
          reporter_id: report.reporter_id,
        },
        content: null,
        target_user: null,
        prior_actions: [],
      });
    } finally {
      setPreviewLoading(false);
    }
  };

  const pickAction = (action) => {
    const report = sheetFor;
    setSheetFor(null);
    if (DANGEROUS.has(action)) {
      setConfirmFor({ report, action });
    } else {
      runAction(report, action, `Moderator action: ${action}`);
    }
  };

  const runAction = async (report, action, reason) => {
    try {
      const targetUserId =
        report.target_type === "profile"
          ? report.target_id
          : preview?.target_user?.id || null;
      await resolveReport({
        reportId: report.id,
        action,
        reason,
        targetType: report.target_type,
        targetId: report.target_id,
        targetUserId,
      });
      showToast(`Action recorded: ${action.replace(/_/g, " ")}`, "success");
      setPreview(null);
      reload();
    } catch (e) {
      showToast(e.message || "Action failed", "error");
      throw e;
    }
  };

  const content = preview?.content;
  const targetUser = preview?.target_user;
  const prior = preview?.prior_actions || [];

  return (
    <>
      <div className="page-header">
        <div>
          <h1 className="page-title">Report queue</h1>
          <p className="page-subtitle">
            {reports.length} open {reports.length === 1 ? "report" : "reports"} awaiting review.
            Open a report to preview the reported content before acting.
          </p>
        </div>
      </div>

      {error && <div className="error-banner">{error}</div>}

      <div className="panel">
        {loading ? (
          <div className="state-block">
            <div className="spinner" />
          </div>
        ) : reports.length === 0 ? (
          <div className="state-block">
            <div className="state-block-title">Queue clear</div>
            <div className="state-block-sub">No open reports.</div>
          </div>
        ) : (
          reports.map((r) => (
            <div className="row" key={r.id}>
              <div className="row-main">
                <div className="row-title">
                  <span className="pill pill-open">{r.target_type}</span>
                  {r.reason}
                </div>
                <div className="row-sub">
                  by @{r.profiles?.username || r.reporter_id.slice(0, 8)} · {timeAgo(r.created_at)}
                </div>
                {r.details && (
                  <div className="row-sub mono" style={{ marginTop: 6 }}>
                    {r.details}
                  </div>
                )}
              </div>
              <div className="row-actions">
                <button className="btn btn-ghost btn-sm" onClick={() => openPreview(r)}>
                  Review
                </button>
              </div>
            </div>
          ))
        )}
      </div>

      {/* Content + user preview drawer */}
      {preview && (
        <div className="modal-backdrop" onClick={() => setPreview(null)}>
          <div className="modal modal-wide" onClick={(e) => e.stopPropagation()}>
            <h3>
              Report · <span className="pill pill-open">{preview.report?.target_type}</span>{" "}
              {preview.report?.reason}
            </h3>
            <div className="row-sub" style={{ marginBottom: 12 }}>
              Reported {timeAgo(preview.report?.created_at)}
              {preview.report?.details && (
                <>
                  <br />
                  <span className="mono">{preview.report.details}</span>
                </>
              )}
            </div>

            {previewLoading ? (
              <div className="state-block">
                <div className="spinner" />
              </div>
            ) : (
              <>
                {/* Reported content */}
                <div className="section-label">Reported content</div>
                {content ? (
                  <div className="content-preview">
                    {content.type === "squad" ? (
                      <>
                        <div className="user-row-identity" style={{ marginBottom: 8 }}>
                          <Avatar url={content.logo_url} name={content.name} size="lg" />
                          <div>
                            <div className="row-title">{content.name}</div>
                            <div className="row-sub">
                              {content.primary_game || "—"} · {content.member_count ?? 0} members ·{" "}
                              {content.is_public ? "Public" : "Private"}
                              {content.is_restricted && " · Restricted"}
                              {content.is_deleted && " · Archived"}
                            </div>
                            <div className="row-sub">
                              Owner @{content.owner_username || "?"}
                            </div>
                          </div>
                        </div>
                        {content.description && (
                          <div className="content-body">{content.description}</div>
                        )}
                      </>
                    ) : (
                      <>
                        <div className="content-author">
                          @{content.author_username || "unknown"}
                          {content.author_gamer_name && (
                            <span className="muted"> · {content.author_gamer_name}</span>
                          )}
                        </div>
                        {(content.body || content.body === "") && (
                          <div className="content-body">{content.body || "(empty body)"}</div>
                        )}
                        {Array.isArray(content.media_urls) && content.media_urls.length > 0 && (
                          <div className="media-thumbs">
                            {content.media_urls.map((url, i) => (
                              <a key={i} href={url} target="_blank" rel="noreferrer" className="media-thumb">
                                {/\.(mp4|webm|mov)(\?|$)/i.test(url) ? (
                                  <span className="media-video-label">Video</span>
                                ) : (
                                  <img src={url} alt="" loading="lazy" />
                                )}
                              </a>
                            ))}
                          </div>
                        )}
                        {content.media_url && (
                          <div className="media-thumbs">
                            <a href={content.media_url} target="_blank" rel="noreferrer" className="media-thumb">
                              <img src={content.media_url} alt="" loading="lazy" />
                            </a>
                          </div>
                        )}
                      </>
                    )}
                    {content.is_deleted && (
                      <div className="pill pill-banned" style={{ marginTop: 8 }}>
                        already deleted
                      </div>
                    )}
                    <div className="row-sub" style={{ marginTop: 8 }}>
                      {content.type} · {content.like_count != null && `${content.like_count} likes · `}
                      {content.comment_count != null && `${content.comment_count} comments · `}
                      {timeAgo(content.created_at)}
                    </div>
                  </div>
                ) : preview.report?.target_type === "profile" ? (
                  <div className="row-sub" style={{ marginBottom: 12 }}>
                    Profile report — see reported user below.
                  </div>
                ) : (
                  <div className="row-sub" style={{ marginBottom: 12 }}>
                    Content could not be loaded (deleted or unavailable).
                  </div>
                )}

                {/* Reported user */}
                <div className="section-label">Reported user</div>
                {targetUser ? (
                  <div className="content-preview">
                    <div className="user-row-identity" style={{ marginBottom: 8 }}>
                      <Avatar url={targetUser.avatar_url} name={targetUser.gamer_name || targetUser.username} size="lg" />
                      <div>
                        <div className="row-title">
                          @{targetUser.username}
                          {targetUser.gamer_name && (
                            <span className="muted"> · {targetUser.gamer_name}</span>
                          )}
                          {targetUser.is_verified && (
                            <span className="pill pill-verified">verified</span>
                          )}
                          {targetUser.is_banned && <span className="pill pill-banned">banned</span>}
                          {targetUser.is_restricted && (
                            <span className="pill pill-restricted">restricted</span>
                          )}
                        </div>
                        <div className="row-sub">
                          Role: {targetUser.app_role || "user"} · Joined {timeAgo(targetUser.created_at)}
                        </div>
                      </div>
                    </div>
                  </div>
                ) : (
                  <div className="row-sub" style={{ marginBottom: 12 }}>
                    User profile unavailable.
                  </div>
                )}

                {/* Prior moderation */}
                <div className="section-label">Previous moderation actions</div>
                {prior.length === 0 ? (
                  <div className="row-sub" style={{ marginBottom: 12 }}>
                    No prior actions on this user.
                  </div>
                ) : (
                  <div className="history-list">
                    {prior.map((h, i) => (
                      <div className="history-item" key={i}>
                        <div className="history-action">
                          <span className="pill">{h.action}</span>
                          <span className="muted">by @{h.actor_username || "staff"}</span>
                        </div>
                        <div className="row-sub">
                          {h.reason || "—"} · {timeAgo(h.created_at)}
                        </div>
                      </div>
                    ))}
                  </div>
                )}

                <StaffNotes targetType="report" targetId={preview.report.id} />

                <div className="modal-actions" style={{ marginTop: 16 }}>
                  <button className="btn btn-ghost" onClick={() => setPreview(null)}>
                    Close
                  </button>
                  <button
                    className="btn btn-primary"
                    onClick={() => {
                      // Reconstruct a report-shaped object for the action sheet
                      setSheetFor({
                        id: preview.report.id,
                        target_type: preview.report.target_type,
                        target_id: preview.report.target_id,
                        reason: preview.report.reason,
                        details: preview.report.details,
                        reporter_id: preview.report.reporter_id,
                        created_at: preview.report.created_at,
                      });
                    }}
                  >
                    Take action
                  </button>
                </div>
              </>
            )}
          </div>
        </div>
      )}

      {sheetFor && (
        <ActionSheet
          title={`Resolve: ${sheetFor.target_type} report`}
          options={ACTIONS}
          onSelect={pickAction}
          onCancel={() => setSheetFor(null)}
        />
      )}

      {confirmFor && (
        <ConfirmDialog
          title={`${labelFor(confirmFor.action)}?`}
          description={`This will be recorded against the report and the target ${confirmFor.report.target_type}. This action can't be undone from here.`}
          confirmLabel={labelFor(confirmFor.action)}
          danger
          requireReason
          actionType={confirmFor.action}
          onCancel={() => setConfirmFor(null)}
          onConfirm={async (reason) => {
            await runAction(confirmFor.report, confirmFor.action, reason);
            setConfirmFor(null);
          }}
        />
      )}

      {ToastEl}
    </>
  );
}

function labelFor(action) {
  return ACTIONS.find((a) => a.value === action)?.label || action;
}
