import SwiftUI

struct PaletteCatalogView: View {
    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color.appBackground, Color.appBackgroundSecondary, Color.appBackground],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 14) {
                        PaletteSectionHeader(
                            title: "Colores por categoria",
                            subtitle: "Cada pantalla usa su familia principal."
                        )

                        ForEach(AppPalette.categorizedFamilies) { family in
                            PaletteFamilyCard(family: family)
                        }

                        PaletteSectionHeader(
                            title: "Colores reservados",
                            subtitle: "Disponibles para futuras pantallas."
                        )
                        .padding(.top, 4)

                        ForEach(AppPalette.futureFamilies) { family in
                            PaletteFamilyCard(family: family)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("Paleta de colores")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct PaletteSectionHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline.weight(.bold))
                .fontDesign(.rounded)
                .foregroundStyle(Color.appTextPrimary)

            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Color.appTextSecondary)
        }
    }
}

private struct PaletteFamilyCard: View {
    let family: AppPalette.PaletteFamily

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(family.title)
                    .font(.headline.weight(.semibold))
                    .fontDesign(.rounded)
                    .foregroundStyle(Color.appTextPrimary)

                if let category = family.category {
                    Text(category)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appBackgroundSecondary, in: Capsule())
                } else {
                    Text("Futuro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.appTextSecondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.appBackgroundSecondary, in: Capsule())
                }
            }

            VStack(spacing: 6) {
                ForEach(family.swatches) { swatch in
                    PaletteSwatchRow(familyID: family.id, swatch: swatch)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.appSurface, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.appStrokeSoft, lineWidth: 1)
        )
    }
}

private struct PaletteSwatchRow: View {
    let familyID: String
    let swatch: AppPalette.PaletteSwatch

    var body: some View {
        HStack(spacing: 10) {
            Text("\(familyID)-\(swatch.scale)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: 90, alignment: .leading)

            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(swatch.color)
                .frame(height: 28)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 0.5)
                )

            Text(swatch.hex.uppercased())
                .font(.caption2.monospaced())
                .foregroundStyle(Color.appTextSecondary)
                .frame(width: 80, alignment: .trailing)
        }
    }
}
