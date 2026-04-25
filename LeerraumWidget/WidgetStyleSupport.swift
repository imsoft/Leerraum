import SwiftUI
import WidgetKit

extension View {
    @ViewBuilder
    func leerraumWidgetBackground(_ backgroundView: some View) -> some View {
        if #available(iOSApplicationExtension 17.0, *) {
            containerBackground(for: .widget) {
                backgroundView
            }
        } else {
            background(backgroundView)
        }
    }
}
