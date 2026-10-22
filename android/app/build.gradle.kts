plugins { id("com.android.application"); id("org.jetbrains.kotlin.plugin.compose") }

val launcherResDir = file("src/main/res/drawable-nodpi")
val generatedLauncherIcon = launcherResDir.resolve("schonerledigt_store_icon.png")
val iosLauncherIcon = rootProject.projectDir.parentFile.resolve("SchonErledigt/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")
val generateIosLauncherIcon by tasks.registering(Copy::class) {
    from(iosLauncherIcon)
    into(launcherResDir)
    rename { "schonerledigt_store_icon.png" }
}

android {
    namespace = "com.kamilunavo.schonerledigt"
    compileSdk = 36
    defaultConfig {
        applicationId = "com.kamilunavo.schonerledigt"
        minSdk = 26
        targetSdk = 36
        versionCode = 6
        versionName = "1.1.0"
        testInstrumentationRunner = "androidx.test.runner.AndroidJUnitRunner"
    }
    buildFeatures { compose = true; buildConfig = true }
    compileOptions { sourceCompatibility = JavaVersion.VERSION_17; targetCompatibility = JavaVersion.VERSION_17 }
    buildTypes { release { isMinifyEnabled = true; isShrinkResources = true; proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro") } }
}

tasks.named("preBuild").configure { dependsOn(generateIosLauncherIcon) }

tasks.register("verifyLauncherIconParity") {
    dependsOn(generateIosLauncherIcon)
    doLast {
        check(iosLauncherIcon.readBytes().contentEquals(generatedLauncherIcon.readBytes())) {
            "SchonErledigt Android launcher must be byte-identical to the iOS AppIcon"
        }
    }
}

dependencies {
    constraints {
        implementation("androidx.fragment:fragment:1.9.1") {
            because("Replace the obsolete Fragment 1.1.0 requested transitively by Play services")
        }
    }
    implementation("androidx.core:core-ktx:1.17.0")
    implementation("androidx.activity:activity-compose:1.12.4")
    implementation("androidx.lifecycle:lifecycle-runtime-compose:2.10.0")
    implementation(platform("androidx.compose:compose-bom:2026.06.00"))
    implementation("androidx.compose.foundation:foundation")
    implementation("androidx.compose.material3:material3")
    implementation("androidx.compose.material:material-icons-extended")
    implementation("com.android.billingclient:billing-ktx:9.1.0")
    implementation("com.google.code.gson:gson:2.11.0")
    testImplementation("junit:junit:4.13.2")
    androidTestImplementation(platform("androidx.compose:compose-bom:2026.06.00"))
    androidTestImplementation("androidx.compose.ui:ui-test-junit4")
    androidTestImplementation("androidx.test.ext:junit:1.3.0")
    androidTestImplementation("androidx.test:runner:1.7.0")
    androidTestImplementation("androidx.test.uiautomator:uiautomator:2.3.0")
    debugImplementation("androidx.compose.ui:ui-tooling")
}

// Check both actual runtime graphs; a declaration alone does not prove the packaged version.
tasks.register("verifyFragmentRuntime") {
    doLast {
        listOf("debugRuntimeClasspath", "releaseRuntimeClasspath").forEach { name ->
            val selected = configurations.getByName(name).resolvedConfiguration.resolvedArtifacts.filter {
                it.moduleVersion.id.group == "androidx.fragment" && it.name == "fragment"
            }
            check(selected.size == 1 && selected.single().moduleVersion.id.version == "1.9.1") {
                "Expected Fragment 1.9.1 in $name; found ${selected.map { it.moduleVersion.id }}"
            }
        }
    }
}
