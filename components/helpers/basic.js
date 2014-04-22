(function(){
  var send = function(path, params, method){
    method = method || 'post'

    var form = document.createElement('form')
    form.setAttribute('method', method)
    form.setAttribute('action', path)

    for(var key in params) {
      if(params.hasOwnProperty(key)) {
        var hiddenField = document.createElement('input')
        hiddenField.setAttribute('type', 'hidden')
        hiddenField.setAttribute('name', key)
        hiddenField.setAttribute('value', params[key])
        form.appendChild(hiddenField)
       }
    }

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
      stop()
      if(!window.confirm(e.getAttribute('data-confirm'))) return
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