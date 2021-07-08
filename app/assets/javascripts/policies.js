$(document).ready(function() {
  var rest = $(".cancel_terminate_table tbody tr td:first-child input:checkbox:not(:first)");
  var head = $('#cancel_terminate_people_attributes_0_include_selected');

  if(head.prop('checked') == true){
    rest.attr("disabled", true);
    rest.prop('checked',true);
  }

  head.on('click', function() {
    var select = $(this).prop('checked');

    if (select == true) {
      rest.prop('checked',true);
      rest.attr("disabled", true);
    }else{
      rest.removeAttr("disabled");
    }
  });

  $('input[id^="cancel_terminate_operation"]').on('click', function() {
    var select = $(this).val();
    if (select == 'cancel') {
      $('.benefit_end_date_group').hide();
      $('#cancel_terminate_benefit_end_date').val('');
    }else {
      $('.benefit_end_date_group').show();
    }
  });

  $("#1095A_generation_form #void-policy-ids").hide();

  $("#1095A_generation_form #1095A_generation_form_error").hide();

  $("#1095A_generation_form input:radio[name='type']").change(function(){
    if(this.value == 'void' && this.checked){
      $("#1095A_generation_form #void-policy-ids").show();
    }else{
      $("#1095A_generation_form #void-policy-ids").hide();
    }
  });

  if(typeof autocomplete_items === 'undefined')
    return;

  var options = {
    name: 'autocomplete_items',
    limit: 4,
    local: autocomplete_items
  }
  $('.typeahead').each(function(index, element) {
    $(element).typeahead(options).on('typeahead:selected', function(e, data) {
      {var lookup_id = $(element).attr('data-target');
        $(lookup_id).val(data.id);
      }
    })
  });
});