extends Node

func reduce_magic():
	var result: bool = true
	var numbers: Array = [10, 12, 14, 16, 20, 11]
	result = numbers.reduce(
		func(accum, element):
			var valid_element = element % 2 == 0
			valid_element = valid_element && element > 8
			valid_element = valid_element && element != 18
			return accum && valid_element,
		true
	)
	print(result)
