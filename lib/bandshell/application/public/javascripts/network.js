function show_hide(id_to_show, where) {
  $(where).each(function(k, el) {
    if ($(el).attr('id') == id_to_show) {
      $(el).show( );
    } else {
      $(el).hide( );
    }
  });
}

function update_connection_type_fields() {
  var id_to_show = $("#connection_type").val();
  show_hide(id_to_show, "#connection > div");
}

function update_address_type_fields() {
  var id_to_show = $("#addressing_type").val();
  show_hide(id_to_show, "#address > div");
}

$(function() {
  update_connection_type_fields( );
  update_address_type_fields( );

  $("#connection_type").change(update_connection_type_fields);
  $("#addressing_type").change(update_address_type_fields);
});
