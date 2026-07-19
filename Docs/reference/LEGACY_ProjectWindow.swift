//
//  ProjectWindow.swift (LEGACY - Reference Only)
//  Produciesta
//
//  Created on 2025-11-18.
//  Removed from Produciesta in commit 91353c5 (May 2026)
//
//  This file is preserved as reference for implementing a reusable
//  ProjectWindow UI component. It demonstrates:
//  - Window lifecycle management (load on appear, update on close)
//  - SwiftData integration for loading project models
//  - Error handling when project is not found
//

import SwiftData
import SwiftProyecto
import SwiftUI

/// Window wrapper for project editing.
///
/// Manages lifecycle of a project window:
/// - Updates lastOpenedDate when window appears
/// - Loads project from SwiftData by ID
/// - Shows ProjectView with sidebar (master-detail)
///
@MainActor
struct ProjectWindow: View {
  let projectID: UUID

  @Environment(\.modelContext) private var modelContext
  @State private var project: ProjectModel?

  var body: some View {
    Group {
      if let project = project {
        ProjectView(project: project)
          .id(project.persistentModelID)
      } else {
        ContentUnavailableView {
          Label("Project Not Found", systemImage: "folder.fill")
        } description: {
          Text("The project could not be loaded.")
        }
      }
    }
    .task {
      await loadProject()
    }
    .onDisappear {
      updateLastOpenedDate()
    }
  }

  // MARK: - Project Loading

  private func loadProject() async {
    // Fetch project from SwiftData
    let fetchDescriptor = FetchDescriptor<ProjectModel>(
      predicate: #Predicate { $0.id == projectID }
    )

    do {
      let projects = try modelContext.fetch(fetchDescriptor)
      if let fetchedProject = projects.first {
        self.project = fetchedProject

        // Update lastOpenedDate on window open
        fetchedProject.lastOpenedDate = Date()
        try? modelContext.save()
      }
    } catch {
      debugError("Failed to load project: \(error.localizedDescription)")
    }
  }

  private func updateLastOpenedDate() {
    // Update again when window closes (captures "worked on" time)
    if let project = project {
      project.lastOpenedDate = Date()
      try? modelContext.save()
    }
  }
}

// MARK: - Preview

#Preview {
  return {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(
      for: ProjectModel.self,
      configurations: config
    )

    // Create sample project
    let project = ProjectModel(
      title: "My Series",
      author: "Jane Showrunner",
      season: 1,
      episodes: 12,
      sourceType: .directory,
      sourceName: "My Series",
      sourceRootURL: "/tmp/my-series"
    )
    container.mainContext.insert(project)

    return ProjectWindow(projectID: project.id)
      .modelContainer(container)
      .frame(width: 1000, height: 700)
  }()
}
