import SwiftUI

struct ThemeModePicker: View {
    @Binding var mode: AppThemeMode

    var body: some View {
        Picker("Modo", selection: $mode) {
            ForEach(AppThemeMode.allCases) { option in
                Label(option.title, systemImage: option.icon)
                    .tag(option)
            }
        }
        .pickerStyle(.inline)
    }
}
