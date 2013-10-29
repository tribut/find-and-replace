shell = require 'shell'
path = require 'path'

{fs, $, RootView} = require 'atom'
Q = require 'q'

# Default to 30 second promises
waitsForPromise = (fn) -> window.waitsForPromise timeout: 30000, fn

describe 'ProjectFindView', ->
  [pack, editor, projectFindView, searchPromise] = []

  getExistingResultsPane = ->
    pack.mainModule.getExistingResultsPane()

  beforeEach ->
    window.rootView = new RootView()
    project.setPath(path.join(__dirname, 'fixtures'))
    rootView.openSync('sample.js')
    rootView.attachToDom()
    editor = rootView.getActiveView()
    pack = atom.activatePackage("find-and-replace", immediate: true)
    projectFindView = pack.mainModule.projectFindView

    spy = spyOn(projectFindView, 'confirm').andCallFake ->
      searchPromise = spy.originalValue.call(projectFindView)

  describe "when project-find:show is triggered", ->
    beforeEach ->
      projectFindView.findEditor.setText('items')

    it "attaches ProjectFindView to the root view", ->
      editor.trigger 'project-find:show'
      expect(rootView.find('.project-find')).toExist()
      expect(projectFindView.find('.preview-block')).not.toBeVisible()
      expect(projectFindView.find('.loading')).not.toBeVisible()
      expect(projectFindView.findEditor.getSelectedBufferRange()).toEqual [[0, 0], [0, 5]]

  describe "finding", ->
    describe "when core:cancel is triggered", ->
      beforeEach ->
        editor.trigger 'project-find:show'
        projectFindView.focus()

      it "detaches from the root view", ->
        $(document.activeElement).trigger 'core:cancel'
        expect(rootView.find('.project-find')).not.toExist()

    describe "serialization", ->
      it "serializes if the view is attached", ->
        expect(projectFindView.hasParent()).toBeFalsy()
        editor.trigger 'project-find:show'
        atom.deactivatePackage("find-and-replace")
        pack = atom.activatePackage("find-and-replace", immediate: true)
        projectFindView = pack.mainModule.projectFindView

        expect(projectFindView.hasParent()).toBeTruthy()

      it "serializes if the case and regex options", ->
        editor.trigger 'project-find:show'
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        projectFindView.caseOptionButton.click()
        expect(projectFindView.caseOptionButton).toHaveClass('selected')

        expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
        projectFindView.regexOptionButton.click()
        expect(projectFindView.regexOptionButton).toHaveClass('selected')

        atom.deactivatePackage("find-and-replace")
        pack = atom.activatePackage("find-and-replace", immediate: true)
        projectFindView = pack.mainModule.projectFindView

        expect(projectFindView.caseOptionButton).toHaveClass('selected')
        expect(projectFindView.regexOptionButton).toHaveClass('selected')

    describe "regex", ->
      beforeEach ->
        editor.trigger 'project-find:show'
        projectFindView.findEditor.setText('i(\\w)ems+')
        spyOn(project, 'scan').andCallFake -> Q()

      it "escapes regex patterns by default", ->
        projectFindView.trigger 'core:confirm'
        expect(project.scan.argsForCall[0][0]).toEqual /i\(\\w\)ems\+/gi

      it "toggles regex option via an event and finds files matching the pattern", ->
        expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
        projectFindView.trigger 'project-find:toggle-regex-option'
        expect(projectFindView.regexOptionButton).toHaveClass('selected')
        expect(project.scan.argsForCall[0][0]).toEqual /i(\w)ems+/gi

      it "toggles regex option via a button and finds files matching the pattern", ->
        expect(projectFindView.regexOptionButton).not.toHaveClass('selected')
        projectFindView.regexOptionButton.click()
        expect(projectFindView.regexOptionButton).toHaveClass('selected')
        expect(project.scan.argsForCall[0][0]).toEqual /i(\w)ems+/gi

    describe "case sensitivity", ->
      beforeEach ->
        editor.trigger 'project-find:show'
        spyOn(project, 'scan').andCallFake -> Q()
        projectFindView.findEditor.setText('ITEMS')

      it "runs a case insensitive search by default", ->
        projectFindView.trigger 'core:confirm'
        expect(project.scan.argsForCall[0][0]).toEqual /ITEMS/gi

      it "toggles case sensitive option via an event and finds files matching the pattern", ->
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        projectFindView.trigger 'project-find:toggle-case-option'
        expect(projectFindView.caseOptionButton).toHaveClass('selected')
        expect(project.scan.argsForCall[0][0]).toEqual /ITEMS/g

      it "toggles case sensitive option via a button and finds files matching the pattern", ->
        expect(projectFindView.caseOptionButton).not.toHaveClass('selected')
        projectFindView.caseOptionButton.click()
        expect(projectFindView.caseOptionButton).toHaveClass('selected')
        expect(project.scan.argsForCall[0][0]).toEqual /ITEMS/g

    describe "when core:confirm is triggered", ->
      beforeEach ->
        rootView.trigger 'project-find:show'

      describe "when the there search field is empty", ->
        it "does not run the seach", ->
          spyOn(project, 'scan')
          projectFindView.trigger 'core:confirm'
          expect(project.scan).not.toHaveBeenCalled()

      describe "when results exist", ->
        beforeEach ->
          projectFindView.findEditor.setText('items')

        it "displays the results and no errors", ->
          projectFindView.trigger 'core:confirm'

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            expect(resultsView).toBeVisible()
            resultsView.scrollToBottom() # To load ALL the results
            expect(resultsView.find("li > ul > li")).toHaveLength(13)
            expect(resultsPaneView.previewCount.text()).toBe "13 matches in 2 files for 'items'"
            expect(projectFindView.errorMessages).not.toBeVisible()

        it "only searches paths matching text in the path filter", ->
          spyOn(project, 'scan').andCallFake -> Q()
          projectFindView.pathsEditor.setText('*.js')
          projectFindView.trigger 'core:confirm'

          expect(project.scan.argsForCall[0][1]['paths']).toEqual ['*.js']

        it "updates the results list when a buffer changes", ->
          projectFindView.trigger 'core:confirm'
          buffer = project.bufferForPathSync('sample.js')

          waitsForPromise ->
            searchPromise

          runs ->
            resultsPaneView = getExistingResultsPane()
            resultsView = resultsPaneView.resultsView
            resultsView.scrollToBottom() # To load ALL the results
            expect(resultsView.find("li > ul > li")).toHaveLength(13)
            expect(resultsPaneView.previewCount.text()).toBe "13 matches in 2 files for 'items'"

            buffer.setText('there is one "items" in this file')
            buffer.trigger('contents-modified')

            expect(resultsView.find("li > ul > li")).toHaveLength(8)
            expect(resultsPaneView.previewCount.text()).toBe "8 matches in 2 files for 'items'"

            buffer.setText('no matches in this file')
            buffer.trigger('contents-modified')

            expect(resultsView.find("li > ul > li")).toHaveLength(7)
            expect(resultsPaneView.previewCount.text()).toBe "7 matches in 1 file for 'items'"

      describe "when no results exist", ->
        beforeEach ->
          projectFindView.findEditor.setText('notintheprojectbro')
          spyOn(project, 'scan').andCallFake -> Q()

        it "displays no errors and no results", ->
          projectFindView.trigger 'core:confirm'

          waitsForPromise ->
            searchPromise

          runs ->
            resultsView = getExistingResultsPane().resultsView
            expect(projectFindView.errorMessages).not.toBeVisible()
            expect(resultsView).toBeVisible()
            expect(resultsView.find("li > ul > li")).toHaveLength(0)

    describe "history", ->
      beforeEach ->
        rootView.trigger 'project-find:show'
        spyOn(project, 'scan').andCallFake -> Q()

        projectFindView.findEditor.setText('sort')
        projectFindView.replaceEditor.setText('bort')
        projectFindView.pathsEditor.setText('abc')
        projectFindView.findEditor.trigger 'core:confirm'

        projectFindView.findEditor.setText('items')
        projectFindView.replaceEditor.setText('eyetims')
        projectFindView.pathsEditor.setText('def')
        projectFindView.findEditor.trigger 'core:confirm'

      it "can navigate the entire history stack", ->
        expect(projectFindView.findEditor.getText()).toEqual 'items'

        projectFindView.findEditor.trigger 'core:move-up'
        expect(projectFindView.findEditor.getText()).toEqual 'sort'

        projectFindView.findEditor.trigger 'core:move-down'
        expect(projectFindView.findEditor.getText()).toEqual 'items'

        projectFindView.findEditor.trigger 'core:move-down'
        expect(projectFindView.findEditor.getText()).toEqual ''

        expect(projectFindView.pathsEditor.getText()).toEqual 'def'

        projectFindView.pathsEditor.trigger 'core:move-up'
        expect(projectFindView.pathsEditor.getText()).toEqual 'abc'

        projectFindView.pathsEditor.trigger 'core:move-down'
        expect(projectFindView.pathsEditor.getText()).toEqual 'def'

        projectFindView.pathsEditor.trigger 'core:move-down'
        expect(projectFindView.pathsEditor.getText()).toEqual ''

        expect(projectFindView.replaceEditor.getText()).toEqual 'eyetims'

        projectFindView.replaceEditor.trigger 'core:move-up'
        expect(projectFindView.replaceEditor.getText()).toEqual 'bort'

        projectFindView.replaceEditor.trigger 'core:move-down'
        expect(projectFindView.replaceEditor.getText()).toEqual 'eyetims'

        projectFindView.replaceEditor.trigger 'core:move-down'
        expect(projectFindView.replaceEditor.getText()).toEqual ''

  describe "replacing", ->
    [testDir, sampleJs, sampleCoffee] = []

    beforeEach ->
      testDir = "/tmp/atom-find-and-replace"
      fs.makeTree(testDir)
      sampleJs = path.join(testDir, 'sample.js')
      sampleCoffee = path.join(testDir, 'sample.coffee')

      fs.copy(require.resolve('./fixtures/sample.coffee'), sampleCoffee)
      fs.copy(require.resolve('./fixtures/sample.js'), sampleJs)
      rootView.trigger 'project-find:show'
      project.setPath(testDir)

    afterEach ->
      fs.remove(testDir)

    describe "when the replace button is pressed", ->
      it "runs the search, and replaces all the matches", ->
        projectFindView.findEditor.setText('items')
        projectFindView.trigger 'core:confirm'

        waitsForPromise ->
          searchPromise

        runs ->
          projectFindView.replaceEditor.setText('sunshine')
          projectFindView.replaceAllButton.click()

          expect(projectFindView.errorMessages).not.toBeVisible()
          expect(projectFindView.infoMessages).toBeVisible()
          expect(projectFindView.infoMessages.find('li').text()).toContain 'Replaced'

          sampleJsContent = fs.read sampleJs
          expect(sampleJsContent.match(/items/g)).toBeFalsy()
          expect(sampleJsContent.match(/sunshine/g)).toHaveLength 6

          sampleCoffeeContent = fs.read sampleCoffee
          expect(sampleCoffeeContent.match(/items/g)).toBeFalsy()
          expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength 7

    describe "when the project-find:replace-all is triggered", ->
      describe "when no search has been run", ->
        it "does not replace anything", ->
          spyOn(project, 'scan')
          spyOn(shell, 'beep')
          projectFindView.trigger 'project-find:replace-all'
          expect(project.scan).not.toHaveBeenCalled()
          expect(shell.beep).toHaveBeenCalled()
          expect(projectFindView.infoMessages.find('li').text()).toBe "Nothing replaced"

      describe "when the search text has changed since that last search", ->
        beforeEach ->
          projectFindView.findEditor.setText('items')
          projectFindView.trigger 'core:confirm'

          waitsForPromise ->
            searchPromise

        it "clears the search results and does not replace anything", ->
          spyOn(project, 'scan')
          spyOn(shell, 'beep')

          projectFindView.findEditor.setText('sort')
          expect(projectFindView.resultsView).not.toBeVisible()

          projectFindView.trigger 'project-find:replace-all'
          expect(project.scan).not.toHaveBeenCalled()
          expect(shell.beep).toHaveBeenCalled()
          expect(projectFindView.infoMessages.find('li').text()).toBe "Nothing replaced"

      describe "when the text in the search box triggered the results", ->
        beforeEach ->
          projectFindView.findEditor.setText('items')
          projectFindView.trigger 'core:confirm'

          waitsForPromise ->
            searchPromise

        it "runs the search, and replaces all the matches", ->
          projectFindView.replaceEditor.setText('sunshine')

          projectFindView.trigger 'project-find:replace-all'
          expect(projectFindView.errorMessages).not.toBeVisible()

          resultsPaneView = getExistingResultsPane()
          resultsView = resultsPaneView.resultsView

          expect(resultsView).toBeVisible()
          expect(resultsView.find("li > ul > li")).toHaveLength(0)

          expect(projectFindView.infoMessages.find('li').text()).toBe "Replaced 13 results in 2 files"

          sampleJsContent = fs.read sampleJs
          expect(sampleJsContent.match(/items/g)).toBeFalsy()
          expect(sampleJsContent.match(/sunshine/g)).toHaveLength 6

          sampleCoffeeContent = fs.read sampleCoffee
          expect(sampleCoffeeContent.match(/items/g)).toBeFalsy()
          expect(sampleCoffeeContent.match(/sunshine/g)).toHaveLength 7
