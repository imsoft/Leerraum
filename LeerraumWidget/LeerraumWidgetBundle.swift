import WidgetKit
import SwiftUI

@main
struct LeerraumWidgetBundle: WidgetBundle {
    var body: some Widget {
        LeerraumSummaryWidget()
        LeerraumFoodWidget()
        LeerraumMealsRoutineWidget()
        LeerraumWaterRoutineWidget()
        LeerraumQuoteWidget()
        LeerraumLifeGoalWidget()
    }
}
