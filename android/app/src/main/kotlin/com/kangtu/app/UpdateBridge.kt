package com.kangtu.app

import android.content.Context
import android.content.pm.PackageInfo
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.plugin.common.MethodChannel

/**
 * 应用内更新的原生校验：把「下载的 APK」与「已安装应用」的**签名证书**比对。
 *
 * 为什么需要：APK 从第三方镜像下载，理论上存在被篡改/投毒的可能。
 * Android 自身会拒绝「签名不同」的覆盖安装，但用户只会看到一句含糊的失败；
 * 这里提前比对，能给出**明确理由**并主动拒绝。
 *
 * 返回三态（而不是 bool）：`ok` / `mismatch` / `unreadable`。
 * - `unreadable`：个别 ROM 用 `GET_SIGNING_CERTIFICATES` 拿不到，**会再试一次旧 API**
 *   （`GET_SIGNATURES`，虽已废弃但在这些 ROM 上仍可用）；两次都拿不到才判 unreadable →
 *   界面提示「无法校验，请改用发布页」，而不是让用户以为「签名不符」。
 * - 任何异常一律 `unreadable`（保守：不放行来路不明的包）。
 */
class UpdateBridge(private val context: Context) {

    companion object {
        const val CHANNEL = "gymmane/update"
        const val OK = "ok"
        const val MISMATCH = "mismatch"
        const val UNREADABLE = "unreadable"
    }

    fun handle(call: io.flutter.plugin.common.MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "verifySignature" -> {
                val path = call.argument<String>("path")
                result.success(if (path == null) UNREADABLE else check(path))
            }
            else -> result.notImplemented()
        }
    }

    private fun check(path: String): String = try {
        val pm = context.packageManager
        val downloaded = certsAny(pm.getPackageArchiveInfo(path, flagsNew()))
            ?: certsAny(pm.getPackageArchiveInfo(path, flagsLegacy()))
        val installed = certsAny(pm.getPackageInfo(context.packageName, flagsNew()))
            ?: certsAny(pm.getPackageInfo(context.packageName, flagsLegacy()))
        when {
            downloaded.isNullOrEmpty() || installed.isNullOrEmpty() -> UNREADABLE
            downloaded == installed -> OK
            else -> MISMATCH
        }
    } catch (e: Exception) {
        UNREADABLE
    }

    private fun flagsNew(): Int =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) PackageManager.GET_SIGNING_CERTIFICATES
        else PackageManager.GET_SIGNATURES

    @Suppress("DEPRECATION")
    private fun flagsLegacy(): Int = PackageManager.GET_SIGNATURES

    /** 取签名证书集合；读不到返回 null（好让调用方回退另一种 flag） */
    private fun certsAny(info: PackageInfo?): Set<String>? {
        if (info == null) return null
        val signs = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            info.signingInfo?.apkContentsSigners?.takeIf { it.isNotEmpty() }
                ?: @Suppress("DEPRECATION") info.signatures
        } else {
            @Suppress("DEPRECATION") info.signatures
        } ?: return null
        return signs.map { it.toCharsString() }.toSet()
    }
}
