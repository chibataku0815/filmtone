import FilmLabSwiftCore
import Foundation

// M5-G.1: Snapshot of the values `LibraryViewModel.saveCurrentLook
// (name:payload:)` needs to persist a `SavedLookEntry`. Lifted out of
// `EditorState` so the library feature depends only on the payload
// type, not on the whole `EditorState` (P3 from 2026-05-05 review).
//
// `EditorState.currentLookSavePayload()` is the single canonical
// builder; it remains the only place that knows how to extract this
// from the live render state. `creativeLut` is `.bundled` when a
// built-in Look is active (preserves the slug / filename / pinned sha
// through the save round-trip), `nil` otherwise.
struct SaveLookPayload {
    let presetName: String
    let presetVersion: String
    let strength: Double
    let quickState: FilmtoneQuickState
    let paramOverrides: FilmtonePhase0ParamsPatch
    let creativeLut: CreativeLutBinding?
}
