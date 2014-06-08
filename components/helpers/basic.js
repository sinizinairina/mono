(function(){
  var send = function(path, params, method){
    method = method || 'post'
    method = method.toLowerCase()
    var overrideMethod = ['get', 'post'].indexOf(method) < 0
    var formMethod = overrideMethod ? 'post' : method

    var form = document.createElement('form')
    form.setAttribute('method', formMethod)
    form.setAttribute('action', path)

    var addField = function(name, value){
      var hiddenField = document.createElement('input')
      hiddenField.setAttribute('type', 'hidden')
      hiddenField.setAttribute('name', name)
      hiddenField.setAttribute('value', value)
      form.appendChild(hiddenField)
    }

    for(var name in params)
      if(params.hasOwnProperty(name))
        addField(name, params[name])

    if(overrideMethod) addField('_method', method)

    document.body.appendChild(form)
    form.submit()
  }

  document.addEventListener('click', function(event) {
    var e = event.target
    if(!e) return

    var stop = function(){
      event.preventDefault()
      event.stopPropagation()
    }

    if(e.getAttribute('data-confirm')){
      if(!window.confirm(e.getAttribute('data-confirm'))){
        stop()
        return
      }
    }

    if(e.getAttribute('data-method')){
  	  stop()
  	  var path = e.getAttribute('href') || e.getAttribute('data-path')
  	  send(
  	    (e.getAttribute('href') || e.getAttribute('data-path')),
  	    {},
  	    e.getAttribute('data-method')
	    )
  	}

  })
})()