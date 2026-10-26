allprojects {
    repositories {
        google()
        mavenCentral()
    }
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

subprojects {
    val forceCompileSdk: Project.() -> Unit = {
        extensions.findByName("android")?.withGroovyBuilder {
            "compileSdkVersion"(36)
        }
    }
    if (state.executed) forceCompileSdk() else afterEvaluate { forceCompileSdk() }
}
