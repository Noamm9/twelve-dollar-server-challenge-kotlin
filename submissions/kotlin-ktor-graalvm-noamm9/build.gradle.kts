
plugins {
    alias(libs.plugins.kotlin.jvm)
    alias(ktorLibs.plugins.ktor)
    alias(libs.plugins.kotlin.serialization)
    alias(libs.plugins.graalvm.native)
}

group = "dev.noamm9.velox"
version = "2026.10.1"

application {
    mainClass = "dev.noamm9.velox.MainKt"
}

kotlin {
    jvmToolchain(25)
}

graalvmNative {
    binaries.named("main") {
        imageName.set(rootProject.name)
        mainClass.set(application.mainClass)
        buildArgs.add("-J-Xmx1100m")
    }
}
dependencies {
    implementation(ktorLibs.serialization.kotlinx.json)
    implementation(ktorLibs.server.cio)
    implementation(ktorLibs.server.contentNegotiation)
    implementation(ktorLibs.server.core)
    implementation(ktorLibs.server.statusPages)

    implementation(libs.logback.classic)

    implementation(libs.dotenv)

    implementation(libs.sqlite)
}
