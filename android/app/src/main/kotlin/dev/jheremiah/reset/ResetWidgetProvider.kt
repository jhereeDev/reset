package dev.jheremiah.reset

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Home-screen widget showing today's progress. Data is pushed from Flutter
 * via the home_widget plugin; when the stored date is stale (the app hasn't
 * been opened today) the widget degrades to a friendly prompt instead of
 * showing yesterday's numbers as if they were today's.
 */
class ResetWidgetProvider : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        val isFresh = widgetData.getString("widget_date", null) == today

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.reset_widget)

            if (isFresh) {
                val done = widgetData.getInt("widget_done", 0)
                val total = widgetData.getInt("widget_total", 0)
                views.setTextViewText(R.id.widget_progress, "$done of $total done")
                views.setProgressBar(R.id.widget_bar, maxOf(total, 1), done, false)
                views.setTextViewText(
                    R.id.widget_habits,
                    widgetData.getString("widget_lines", "") ?: "",
                )
            } else {
                views.setTextViewText(R.id.widget_progress, "Ready for today")
                views.setProgressBar(R.id.widget_bar, 1, 0, false)
                views.setTextViewText(
                    R.id.widget_habits,
                    "Open Reset to log your first win",
                )
            }
            views.setTextViewText(
                R.id.widget_streak,
                widgetData.getString("widget_streak", "") ?: "",
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
