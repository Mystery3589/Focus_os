import com.android.build.api.dsl.ApplicationExtension
import com.android.build.api.dsl.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// Keep Android plugin subprojects aligned with the toolchain Flutter/AGP expects.
// This also reduces noisy JDK warnings like:
//   "source value 8 is obsolete and will be removed in a future release"
// which can appear when building plugin modules with -source/-target 1.8 on newer JDKs.
subprojects {
    plugins.withId("com.android.application") {
        extensions.configure<ApplicationExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    plugins.withId("com.android.library") {
        extensions.configure<LibraryExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_17
                targetCompatibility = JavaVersion.VERSION_17
            }
        }
    }

    // NOTE: Kotlin's older `kotlinOptions { jvmTarget = ... }` usage is deprecated
    // and must be migrated to the new compilerOptions/toolchain DSL. The app
    // module already sets the Kotlin jvmTarget in `app/build.gradle.kts`, so we
    // avoid calling `kotlinOptions` here to prevent Kotlin DSL errors during
    // script compilation. If you need to enforce a Kotlin toolchain across
    // plugin subprojects, migrate to the `kotlin { jvmToolchain(17) }` or the
    // newer `compilerOptions` DSL per the Kotlin Gradle plugin docs.
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
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
