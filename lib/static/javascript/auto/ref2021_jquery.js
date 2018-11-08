/*If we have jQuery use it to further colour in the selection citations with traffic light colours */
if (window.jQuery) {
    jQuery(document).ready(function() {

      jQuery(".hoa_future_compliant_icon").closest("td").css("border-left", "7px solid rgb(225, 145, 65)");
      jQuery(".hoa_warning_icon").closest("td").css("border-left", "7px solid #C41F1F");
      jQuery(".hoa_compliant_icon").closest("td").css("border-left", "7px solid #1F7E02");
    });
}
