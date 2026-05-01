import Foundation
import SwiftUI


enum SavedLookSheetMode: Identifiable {
    case createCurrentLook
    case renameLook(SavedLookEntry)
    case renameLut(LutLibraryEntry)

    var id: String {
        switch self {
        case .createCurrentLook:
            return "create"
        case .renameLook(let entry):
            return "renameLook-\(entry.id.uuidString)"
        case .renameLut(let entry):
            return "renameLut-\(entry.id.uuidString)"
        }
    }

    var sheetMode: FilmtoneSavedLookSheet.Mode {
        switch self {
        case .createCurrentLook:
            return .create
        case .renameLook, .renameLut:
            return .rename
        }
    }

    func initialName(defaultIndex: Int) -> String {
        switch self {
        case .createCurrentLook:
            return "Look \(defaultIndex)"
        case .renameLook(let entry):
            return entry.name
        case .renameLut(let entry):
            return entry.title
        }
    }
}

final class FilmtoneRootHostingController: UIHostingController<FilmtoneRootView> {
    private let store: FilmtoneEditorStore

    init(store: FilmtoneEditorStore) {
        self.store = store
        super.init(rootView: FilmtoneRootView(store: store))
        store.attachPresenter(self)
        view.backgroundColor = .black
    }

    @MainActor @objc required dynamic init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

