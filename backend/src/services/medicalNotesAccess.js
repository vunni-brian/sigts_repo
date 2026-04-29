// Field-level access control for tourist medical notes.
//
// `medical_notes` is a sensitive PII field. It must only be readable by:
//   * The tourist themselves
//   * IT managers (for support/incident response)
//   * The guide CURRENTLY ASSIGNED to an ACTIVE tour the tourist is
//     participating in (and only while the tour status is 'ongoing').
//
// All other roles, and inactive tour assignments, see the field as null.

const { pool } = require('../config/database');

async function canViewMedicalNotes({ requestingUser, touristUserId }) {
    if (!requestingUser || !touristUserId) return false;

    if (requestingUser.user_id === touristUserId) return true;
    if (requestingUser.user_type === 'it_manager') return true;

    if (requestingUser.user_type !== 'guide') return false;

    const result = await pool.query(
        `SELECT 1
         FROM tour_sessions ts
         JOIN tour_participants tp ON tp.tour_session_id = ts.tour_session_id
         JOIN tourists t ON t.tourist_id = tp.tourist_id
         JOIN tour_guides g ON g.tourguide_id = ts.tourguide_id
         WHERE ts.status = 'ongoing'
           AND g.user_id = $1
           AND t.user_id = $2
         LIMIT 1`,
        [requestingUser.user_id, touristUserId]
    );

    return result.rows.length > 0;
}

// Strips medical_notes from a tourist record unless the requesting user is
// allowed to see it. Mutates a shallow copy and returns it.
async function redactMedicalNotes(tourist, requestingUser) {
    if (!tourist) return tourist;
    const touristUserId = tourist.user_id;
    const allowed = await canViewMedicalNotes({ requestingUser, touristUserId });
    if (allowed) return tourist;

    const redacted = { ...tourist };
    delete redacted.medical_notes;
    delete redacted.medical_notes_updated_at;
    return redacted;
}

module.exports = { canViewMedicalNotes, redactMedicalNotes };
