/* a C struct with bit-fields, which Kelvin cannot declare */
struct bits { unsigned int bf : 3; int sbf : 5; };
static struct bits bb = {7, -16};
