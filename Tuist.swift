import ProjectDescription

let tuist = Tuist(
    fullHandle: "verdigris/verdigris",
    project: .tuist(
        generationOptions: .options(
            enforceExplicitDependencies: true
        )
    )
)
