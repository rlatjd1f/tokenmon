import SwiftUI
import TokenmonPersistence

enum TokenmonDexSpriteStage: String, CaseIterable, Identifiable {
    case portrait
    case spawn
    case resolveSuccess
    case resolveEscape

    var id: String { rawValue }

    var title: String {
        switch self {
        case .portrait:
            return "Portrait"
        case .spawn:
            return "Spawn"
        case .resolveSuccess:
            return "Capture"
        case .resolveEscape:
            return "Escape"
        }
    }

    var detail: String {
        switch self {
        case .portrait:
            return "Dex hero art"
        case .spawn:
            return "Scene renderer preview"
        case .resolveSuccess:
            return "Shared capture scene"
        case .resolveEscape:
            return "Shared escape scene"
        }
    }

    var spriteSize: CGFloat {
        56
    }
}

struct TokenmonDexSpriteInspectorSection: View {
    let entry: DexEntrySummary

    private let columns = [
        GridItem(.adaptive(minimum: 118, maximum: 148), spacing: 12),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Visual States")
                    .font(.headline)
                Text("Encounter states use the shared scene renderer. Species-specific runtime exports are portrait-only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(TokenmonDexSpriteStage.allCases) { stage in
                    TokenmonDexSpriteStateCard(entry: entry, stage: stage)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TokenmonDexSpriteStateCard: View {
    let entry: DexEntrySummary
    let stage: TokenmonDexSpriteStage

    private let layout = TokenmonSceneLayout.statusStrip
    private let sceneScale: CGFloat = 2.6

    private var hasPortrait: Bool {
        TokenmonSpeciesSpriteLoader.hasImage(assetKey: entry.assetKey, variants: [.portrait64, .portrait32])
    }

    private var sceneContext: TokenmonSceneContext? {
        switch stage {
        case .spawn:
            return TokenmonSceneContext(
                sceneState: .spawn,
                fieldKind: .init(fieldType: entry.field),
                fieldState: .rustle,
                effectState: .none,
                wildState: .spawning,
                wildAssetKey: entry.assetKey
            )
        case .resolveSuccess:
            return TokenmonSceneContext(
                sceneState: .resolveSuccess,
                fieldKind: .init(fieldType: entry.field),
                fieldState: .settle,
                effectState: .captureSnap,
                wildState: .captured,
                wildAssetKey: entry.assetKey
            )
        case .resolveEscape:
            return TokenmonSceneContext(
                sceneState: .resolveEscape,
                fieldKind: .init(fieldType: entry.field),
                fieldState: .settle,
                effectState: .escapeDash,
                wildState: .escaped,
                wildAssetKey: entry.assetKey
            )
        case .portrait:
            return nil
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(fieldTint.opacity(0.10))
                RoundedRectangle(cornerRadius: 14)
                    .stroke(rarityTint.opacity(0.24), lineWidth: 1)

                if let sceneContext {
                    TokenmonSceneCanvas(context: sceneContext, tick: 3)
                        .frame(
                            width: layout.canvasSize.width,
                            height: layout.canvasSize.height,
                            alignment: .topLeading
                        )
                        .scaleEffect(sceneScale, anchor: .topLeading)
                        .frame(
                            width: layout.canvasSize.width * sceneScale,
                            height: layout.canvasSize.height * sceneScale,
                            alignment: .topLeading
                        )
                        .clipped()
                } else if hasPortrait {
                    TokenmonSpeciesSpriteImage(
                        assetKey: entry.assetKey,
                        variants: [.portrait64, .portrait32],
                        revealStage: .revealed
                    )
                    .frame(width: stage.spriteSize, height: stage.spriteSize)
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "exclamationmark.square")
                            .font(.system(size: stage.spriteSize * 0.45, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Missing")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .frame(height: 92)

            VStack(alignment: .leading, spacing: 3) {
                Text(stage.title)
                    .font(.caption.weight(.semibold))
                Text(sceneContext != nil || hasPortrait ? stage.detail : "Missing portrait")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.secondary.opacity(0.10), lineWidth: 1)
        )
    }

    private var fieldTint: Color {
        switch entry.field {
        case .grassland:
            return Color(red: 0.27, green: 0.63, blue: 0.35)
        case .ice:
            return Color(red: 0.44, green: 0.72, blue: 0.96)
        case .coast:
            return Color(red: 0.17, green: 0.54, blue: 0.79)
        case .sky:
            return Color(red: 0.29, green: 0.54, blue: 0.88)
        }
    }

    private var rarityTint: Color {
        switch entry.rarity {
        case .common:
            return .secondary
        case .uncommon:
            return Color(red: 0.28, green: 0.63, blue: 0.41)
        case .rare:
            return Color(red: 0.22, green: 0.48, blue: 0.86)
        case .epic:
            return Color(red: 0.71, green: 0.35, blue: 0.86)
        case .legendary:
            return Color(red: 0.92, green: 0.67, blue: 0.14)
        }
    }
}
