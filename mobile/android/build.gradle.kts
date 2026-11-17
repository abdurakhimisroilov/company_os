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

gradle.taskGraph.whenReady {
    allTasks.forEach { task ->
        if (task.name.contains("lint") || task.name.contains("Lint")) {
            task.enabled = false
        }
        if (task.name.contains("sync") && task.name.contains("LibJars")) {
            task.doFirst {
                val buildDir = project.layout.buildDirectory.get().asFile
                val typedefDir = File(buildDir, "intermediates/annotations_typedef_file/release/extractReleaseAnnotations")
                if (!typedefDir.exists()) {
                    typedefDir.mkdirs()
                }
                val typedefFile = File(typedefDir, "typedefs.txt")
                if (!typedefFile.exists()) {
                    typedefFile.createNewFile()
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
