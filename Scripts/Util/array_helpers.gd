class_name ArrayHelpers extends Object

static func is_array_subset_of_other(array: Array, other: Array) -> bool:
	for element in array:
		if !other.has(element):
			return false
	return true

static func append_unique(array: Array, elements_to_append: Array):
	for element in elements_to_append:
		if !array.has(element):
			array.append(element)
