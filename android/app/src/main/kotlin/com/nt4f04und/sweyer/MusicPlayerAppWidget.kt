package com.nt4f04und.sweyer

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProviderInfo
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.res.Resources
import android.graphics.*
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.CancellationSignal
import android.os.OperationCanceledException
import android.util.Log
import android.util.Size
import android.util.TypedValue
import android.view.KeyEvent
import android.view.View.GONE
import android.view.View.VISIBLE
import android.widget.RemoteViews
import es.antonborri.home_widget.*
import java.io.IOException
import java.net.URISyntaxException
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.roundToInt
import com.nt4f04und.sweyer.sweyer_plugin.Constants

/**
 * Sweyer music App Widget.
 * The widget is freely resizable and has a playback control button bar at the bottom.
 * Depending on the horizontal size available, there is eiter just a play/pause button,
 * a play/pause and skip button, or a play/pause, skip and previous button.
 * The background is the current song cover if available. The edges of the widget are rounded.
 */
class MusicPlayerAppWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences
    ) = updateWidgets(context, WidgetInfoProvider(context, appWidgetManager, appWidgetIds), widgetData)

    override fun onAppWidgetOptionsChanged(
        context: Context?, appWidgetManager: AppWidgetManager?, appWidgetId: Int, newOptions: Bundle?
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        if (context == null || appWidgetManager == null) {
            return
        }
        updateWidgets(
            context,
            WidgetInfoProvider(context, appWidgetManager, intArrayOf(appWidgetId), newOptions),
            HomeWidgetPlugin.getData(context),
        )
    }

    /**
     * Update all widgets for the current playback state and their widget size.
     * [widgetData] contains the current play state and currently playing song.
     */
    private fun updateWidgets(context: Context, widgetInfoProvider: WidgetInfoProvider, widgetData: SharedPreferences) {
        val playing = widgetData.getBoolean("playing", false)
        val songUri = try {
            widgetData.getString("song", null)?.let { uri -> Uri.parse(uri) }
        } catch (ignored: URISyntaxException) {
            null
        }
        if (songUri == null || Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
            widgetInfoProvider.updateAll { size ->
                buildUi(context, size, playing)
            }
            return
        }
        val signal = CancellationSignal()
        Executors.newSingleThreadExecutor().execute {
            val bitmap = try {
                context.contentResolver.loadThumbnail(songUri, widgetInfoProvider.maxSize.square(), signal)
            } catch (ignored: OperationCanceledException) {
                null
            } catch (error: IOException) {
                Log.w(Constants.LogTag, "Song thumbnail load failed for $songUri", error)
                null
            }
            widgetInfoProvider.updateAll { size ->
                buildUi(context, size, playing, bitmap)
            }
        }
    }

    /**
     * Build the UI of an app widget instance for the given [size] and [playing] state.
     * If available, use the [songArt] as a background image.
     */
    private fun buildUi(
        context: Context,
        size: Size,
        playing: Boolean,
        songArt: Bitmap? = null,
    ): RemoteViews {
        return RemoteViews(context.packageName, R.layout.music_player_widget).apply {
            // Open App on Widget Click
            val pendingIntent = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            setOnClickPendingIntent(android.R.id.background, pendingIntent)
            setOnClickPendingIntent(
                R.id.music_player_widget_play_pause_button, AudioServiceBackgroundIntent.getPlayPause(context)
            )
            setOnClickPendingIntent(
                R.id.music_player_widget_previous_button, AudioServiceBackgroundIntent.getPrevious(context)
            )
            setOnClickPendingIntent(
                R.id.music_player_widget_skip_next_button, AudioServiceBackgroundIntent.getNext(context)
            )
            if (songArt != null) {
                setImageViewBitmap(
                    R.id.music_player_widget_song_art,
                    // On Android versions since S the system rounds the corners for us.
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) songArt else createRoundedBitmap(
                        songArt, size, context.resources.getDimension(R.dimen.appWidgetRadius)
                    )
                )
                setViewVisibility(R.id.music_player_widget_song_art, VISIBLE)
                setViewVisibility(R.id.music_player_widget_no_song_art, GONE)
            } else {
                setViewVisibility(R.id.music_player_widget_song_art, GONE)
                setViewVisibility(R.id.music_player_widget_no_song_art, VISIBLE)
            }
            val imageButtonWidth = context.resources.getDimension(R.dimen.musicPlayerWidgetButtonSize)
            setViewVisibility(
                R.id.music_player_widget_previous_button, if (size.width < imageButtonWidth * 3) GONE else VISIBLE
            )
            setViewVisibility(
                R.id.music_player_widget_skip_next_button, if (size.width < imageButtonWidth * 2) GONE else VISIBLE
            )
            setViewVisibility(
                R.id.music_player_widget_play_pause_button, if (size.width < imageButtonWidth) GONE else VISIBLE
            )
            setImageViewResource(
                R.id.music_player_widget_play_pause_button,
                if (playing) R.drawable.round_pause else R.drawable.round_play_arrow
            )
        }
    }

    /**
     * Convert the given [bitmap] into a bitmap of the given [size] with rounded corners with the given [cornerRadius].
     */
    private fun createRoundedBitmap(bitmap: Bitmap, size: Size, cornerRadius: Float): Bitmap {
        val scaleFactor = max(size.width / bitmap.width.toDouble(), size.height / bitmap.height.toDouble())
        val matrix = Matrix()
        matrix.setScale(scaleFactor.toFloat(), scaleFactor.toFloat())
        val xOffset = ((bitmap.width - (size.width / scaleFactor)) / 2.0).roundToInt()
        val yOffset = ((bitmap.height - (size.height / scaleFactor)) / 2.0).roundToInt()
        val scaledBitmap = Bitmap.createBitmap(
            bitmap,
            xOffset,
            yOffset,
            (size.width / scaleFactor).roundToInt(),
            (size.height / scaleFactor).roundToInt(),
            matrix,
            true
        )
        val imageRounded = Bitmap.createBitmap(size.width, size.height, bitmap.config)
        val canvas = Canvas(imageRounded)
        val paint = Paint()
        paint.isAntiAlias = true
        paint.shader = BitmapShader(scaledBitmap, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        canvas.drawRoundRect(
            RectF(0f, 0f, size.width.toFloat(), size.height.toFloat()), cornerRadius, cornerRadius, paint
        )
        return imageRounded
    }
}

/**
 * Utility class for calculating and updating sizing information for the app widgets.
 */
internal class WidgetInfoProvider(
    private val context: Context,
    private val appWidgetManager: AppWidgetManager,
    private val appWidgetIds: IntArray,
    newOptions: Bundle? = null
) {
    /**
     * The [sizes] of all instances of this app widget on the home screen, as well as the [max] size.
     */
    class SizeInfo(val sizes: Array<Size>, val max: Size)

    /**
     * Information about the sizes of all instances of this widget on the home screen.
     */
    private val sizeInfo = calculateSizes(newOptions)

    /**
     * The maximum size of all instances of this widget on the home screen.
     */
    val maxSize = sizeInfo.max

    /*
     * Calculate size information of all instances of the widget on the home screen,
     * using the [newOptions] if available.
     */
    private fun calculateSizes(newOptions: Bundle? = null): SizeInfo {
        var maxWidth = 0
        var maxHeight = 0
        val isPortraitOrientation = context.resources.getBoolean(R.bool.isPortraitScreen)
        val sizes = appWidgetIds.map { appWidgetId ->
            val width: Int
            val height: Int

            // Get current dimensions (in DIP, scaled by DisplayMetrics) of this
            // Widget, if API Level allows to
            val mAppWidgetOptions = newOptions ?: appWidgetManager.getAppWidgetOptions(appWidgetId)
            if (mAppWidgetOptions != null && mAppWidgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH) > 0) {
                if (isPortraitOrientation) { // Depends on the home-screen orientation
                    width = mAppWidgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH).dipToPixels()
                    height = mAppWidgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT).dipToPixels()
                } else {
                    width = mAppWidgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_WIDTH).dipToPixels()
                    height = mAppWidgetOptions.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT).dipToPixels()
                }
            } else {
                // Get min dimensions from provider info
                val providerInfo: AppWidgetProviderInfo? = appWidgetManager.getAppWidgetInfo(appWidgetId)
                if (providerInfo == null) {
                    val displayMetrics = Resources.getSystem().displayMetrics
                    width = displayMetrics.widthPixels
                    height = displayMetrics.heightPixels
                } else {
                    width = providerInfo.minWidth.dipToPixels()
                    height = providerInfo.minHeight.dipToPixels()
                }
            }
            if (maxWidth < width) {
                maxWidth = width
            }
            if (maxHeight < height) {
                maxHeight = height
            }
            Size(width, height)
        }.toTypedArray()
        return SizeInfo(sizes, Size(maxWidth, maxHeight))
    }

    /**
     * Update the appearance of each app widget by calling the [builder] with the size of the corresponding widget.
     */
    fun updateAll(builder: (Size) -> RemoteViews) {
        for ((appWidgetId, size) in appWidgetIds.zip(sizeInfo.sizes)) {
            appWidgetManager.updateAppWidget(appWidgetId, builder(size))
        }
    }
}

/**
 * Utility to build background intents to interact with the AudioService from the widget.
 */
object AudioServiceBackgroundIntent {
    /**
     * Build a pending intent for the given [context] emulating a key-press of the given [keyEvent] to the AudioService.
     */
    private fun getIntent(context: Context, keyEvent: KeyEvent): PendingIntent {
        val intent = Intent(context, com.ryanheise.audioservice.AudioService::class.java)
        intent.action = Intent.ACTION_MEDIA_BUTTON
        intent.putExtra(Intent.EXTRA_KEY_EVENT, keyEvent)
        var flags = PendingIntent.FLAG_UPDATE_CURRENT
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            flags = flags or PendingIntent.FLAG_IMMUTABLE
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            intent.identifier = keyEvent.toString()
        } else {
            intent.type = keyEvent.toString()
        }
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(context, 0, intent, flags)
        } else {
            PendingIntent.getService(context, 0, intent, flags)
        }
    }

    /**
     * Create an intent that emulates pressing the media play/pause button.
     */
    fun getPlayPause(context: Context): PendingIntent =
        getIntent(context, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE))

    /**
     * Create an intent that emulates pressing the media next button.
     */
    fun getNext(context: Context): PendingIntent =
        getIntent(context, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_NEXT))

    /**
     * Create an intent that emulates pressing the media previous button.
     */
    fun getPrevious(context: Context): PendingIntent =
        getIntent(context, KeyEvent(KeyEvent.ACTION_DOWN, KeyEvent.KEYCODE_MEDIA_PREVIOUS))
}

/**
 * Convert a float DPI value to pixels.
 */
internal fun Float.dipToPixels() = TypedValue.applyDimension(
    TypedValue.COMPLEX_UNIT_DIP, this, Resources.getSystem().displayMetrics
)

/**
 * Convert an integer DPI value to rounded pixels.
 */
internal fun Int.dipToPixels() = toFloat().dipToPixels().roundToInt()

/**
 * Get a size with equal length sides from the maximum side length of this Size.
 */
internal fun Size.square(): Size {
    val maxSize = max(width, height)
    return Size(maxSize, maxSize)
}
