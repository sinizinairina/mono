require '../helper'
require '../../mono/http'
{app} = require '../../support'

Router = require '../../components/router'

describe "Router", ->
  beforeEach ->
    @router = new Router()
    @router.app = app
    [@createdRoutes, @createdNamedPaths, @createdRoutesOrdered] = [{}, {}, []]
    @router.route = (method, path, {action, controller, prefix}) =>
      @createdRoutes["#{method}:#{prefix || ''}#{path}"] = "#{controller}.#{action}"
      @createdRoutesOrdered.push "#{method}:#{prefix || ''}#{path}"
    @router._namedPath = (name, fn) => @createdNamedPaths[name] = fn

    @checkRoutes = (expectedRoutes) ->
      for [path, action] in expectedRoutes
        expect(@createdRoutes).to.have.property path
        expect(@createdRoutes[path]).to.eql action
    @checkNamedPaths = (expectedNamedPats) ->
      for [namedRoute, args, path] in expectedNamedPats
        expect(@createdNamedPaths).to.have.property namedRoute
        expect(@createdNamedPaths[namedRoute](args...)).to.eql path

  it "should declare plural resource", ->
    @router.resource 'posts'

    @checkRoutes [
      ['get:/posts',          'Posts.index']
      ['get:/posts/new',      'Posts.new']
      ['post:/posts',         'Posts.create']
      ['get:/posts/:id',      'Posts.show']
      ['get:/posts/:id/edit', 'Posts.edit']
      ['put:/posts/:id',      'Posts.update']
      ['delete:/posts/:id',   'Posts.destroy']
    ]

    @checkNamedPaths [
      ['postsPath',    [],     '/posts']
      ['newPostPath',  [],     '/posts/new']
      ['postPath',     ['p1'], '/posts/p1']
      ['editPostPath', ['p1'], '/posts/p1/edit']
    ]

  it "should declare singular resource", ->
    @router.resource 'profile'

    @checkRoutes [
      ['get:/profile',      'Profile.show']
      ['get:/profile/new',  'Profile.new']
      ['post:/profile',     'Profile.create']
      ['get:/profile/edit', 'Profile.edit']
      ['put:/profile',      'Profile.update']
      ['delete:/profile',   'Profile.destroy']
    ]

    @checkNamedPaths [
      ['profilePath',     [], '/profile']
      ['newProfilePath',  [], '/profile/new']
      ['editProfilePath', [], '/profile/edit']
    ]

  it "should declare members and collections", ->
    @router.resource 'posts', (posts) ->
        posts.member     'post', action: 'publish'
        posts.collection 'get',  action: 'count'

    @checkRoutes [
      ['get:/posts/count',        'Posts.count']
      ['post:/posts/:id/publish', 'Posts.publish']
    ]

    @checkNamedPaths [
      ['countPostsPath',  [],     '/posts/count']
      ['publishPostPath', ['p1'], '/posts/p1/publish']
    ]

  it "should declare nested plural resource", ->
    @router.resource 'posts', (posts) ->
      posts.resource 'comments'

    @checkRoutes [
      ['get:/posts',          'Posts.index']
      ['get:/posts/new',      'Posts.new']
      ['post:/posts',         'Posts.create']
      ['get:/posts/:id',      'Posts.show']
      ['get:/posts/:id/edit', 'Posts.edit']
      ['put:/posts/:id',      'Posts.update']
      ['delete:/posts/:id',   'Posts.destroy']

      ['get:/posts/:postId/comments',          'Comments.index']
      ['get:/posts/:postId/comments/new',      'Comments.new']
      ['post:/posts/:postId/comments',         'Comments.create']
      ['get:/posts/:postId/comments/:id',      'Comments.show']
      ['get:/posts/:postId/comments/:id/edit', 'Comments.edit']
      ['put:/posts/:postId/comments/:id',      'Comments.update']
      ['delete:/posts/:postId/comments/:id',   'Comments.destroy']
    ]

    @checkNamedPaths [
      ['postsPath',    [],     '/posts']
      ['newPostPath',  [],     '/posts/new']
      ['postPath',     ['p1'], '/posts/p1']
      ['editPostPath', ['p1'], '/posts/p1/edit']

      ['postCommentsPath',    ['p1'],       '/posts/p1/comments']
      ['newPostCommentPath',  ['p1'],       '/posts/p1/comments/new']
      ['postCommentPath',     ['p1', 'c1'], '/posts/p1/comments/c1']
      ['editPostCommentPath', ['p1', 'c1'], '/posts/p1/comments/c1/edit']
    ]

  it "should declare nested singular resource", ->
    @router.resource 'profile', (profile) ->
      profile.resource 'comments'

    @checkRoutes [
      ['get:/profile/new',  'Profile.new']
      ['post:/profile',     'Profile.create']
      ['get:/profile',      'Profile.show']
      ['get:/profile/edit', 'Profile.edit']
      ['put:/profile',      'Profile.update']
      ['delete:/profile',   'Profile.destroy']

      ['get:/profile/comments',          'Comments.index']
      ['get:/profile/comments/new',      'Comments.new']
      ['post:/profile/comments',         'Comments.create']
      ['get:/profile/comments/:id',      'Comments.show']
      ['get:/profile/comments/:id/edit', 'Comments.edit']
      ['put:/profile/comments/:id',      'Comments.update']
      ['delete:/profile/comments/:id',   'Comments.destroy']
    ]

    @checkNamedPaths [
      ['profilePath',     [], '/profile']
      ['newProfilePath',  [], '/profile/new']
      ['editProfilePath', [], '/profile/edit']

      ['profileCommentsPath',    [],     '/profile/comments']
      ['newProfileCommentPath',  [],     '/profile/comments/new']
      ['profileCommentPath',     ['c1'], '/profile/comments/c1']
      ['editProfileCommentPath', ['c1'], '/profile/comments/c1/edit']
    ]

  it "should declare members and collections on nested resource", ->
    @router.resource 'posts', (posts) ->
      posts.resource 'comments', (comments) ->
        comments.member     'post', action: 'publish'
        comments.collection 'get',  action: 'count'

    @checkRoutes [
      ['get:/posts/:postId/comments/count',        'Comments.count']
      ['post:/posts/:postId/comments/:id/publish', 'Comments.publish']
    ]

    @checkNamedPaths [
      ['countPostCommentsPath',  ['p1'],       '/posts/p1/comments/count']
      ['publishPostCommentPath', ['p1', 'c1'], '/posts/p1/comments/c1/publish']
    ]

  it "should throw error if id required for named path but not provided", ->
    @router.resource 'posts', (posts) ->
      posts.resource 'comments'

    expect(=> @createdNamedPaths.postPath()).to.throw /no.*id.*for.*postPath/
    expect(=> @createdNamedPaths.postCommentsPath()).to.throw /no.*postId.*for.*postCommentsPath/
    expect(=> @createdNamedPaths.postCommentPath('p1')).to.throw /no.*id.*for.*postCommentPath/

  it "should allow to set prefix and controller", ->
    @router.resource 'posts', controller: 'SomeSpecialPosts'
    , prefix: '/special', namedRoutePrefix: 'someSpecial'

    @checkRoutes [
      ['get:/special/posts',     'SomeSpecialPosts.index']
      ['get:/special/posts/:id', 'SomeSpecialPosts.show']
    ]

    @checkNamedPaths [
      ['someSpecialPostsPath', [],     '/special/posts']
      ['someSpecialPostPath',  ['p1'], '/special/posts/p1']
    ]

  it "should declare deep nested plural resource", ->
    @router.resource 'users', (users) ->
      users.resource 'posts', (posts) ->
        posts.resource 'comments'

    @checkRoutes [
      ['get:/users/:userId/posts/:postId/comments', 'Comments.index']
    ]

    @checkNamedPaths [
      ['userPostCommentsPath',    ['u1', 'p1'],       '/users/u1/posts/p1/comments']
    ]

  it "should order routes properly", ->
    @router.resource 'posts', (posts) ->
      posts.member     'post', action: 'publish'
      posts.collection 'get',  action: 'count'
      posts.resource 'comments', (comments) ->
        comments.member     'post', action: 'publish'
        comments.collection 'get',  action: 'count'

    expect(@createdRoutesOrdered).to.eql [
      # Member and collection routes should be first.
      'post:/posts/:id/publish'
      'get:/posts/count'

      # Standard resource routes should be second.
      'get:/posts'
      'get:/posts/new'
      'post:/posts'
      'get:/posts/:id'
      'get:/posts/:id/edit'
      'put:/posts/:id'
      'delete:/posts/:id'

      # Nested routes should be last.
      'post:/posts/:postId/comments/:id/publish'
      'get:/posts/:postId/comments/count'

      'get:/posts/:postId/comments'
      'get:/posts/:postId/comments/new'
      'post:/posts/:postId/comments'
      'get:/posts/:postId/comments/:id'
      'get:/posts/:postId/comments/:id/edit'
      'put:/posts/:postId/comments/:id'
      'delete:/posts/:postId/comments/:id'
    ]