allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Redirect build outputs to <project root>/build/<module>, matching the
// standard Flutter template. This matters because Flutter's own Gradle
// plugin copies the built APK to `<module build dir>/outputs/flutter-apk/`,
// and the Flutter CLI's final relocation step to
// `<project root>/build/app/outputs/flutter-apk/` only works when it can
// detect the AGP version via a legacy `buildscript {}` block — which this
// project doesn't have (it uses the modern AGP plugin DSL). Without this
// redirect, that final step silently no-ops and `flutter build apk` reports
// "failed to produce an .apk file" even though Gradle built it successfully.
// See https://github.com/flutter/flutter/issues/174620
val newBuildDir: Directory = rootProject.layout.buildDirectory.dir("../../build").get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}