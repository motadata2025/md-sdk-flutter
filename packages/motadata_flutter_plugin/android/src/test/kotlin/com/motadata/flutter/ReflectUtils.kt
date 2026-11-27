/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2016-Present Datadog, Inc.
 */
package com.motadata.flutter

import java.lang.reflect.InvocationTargetException
import java.lang.reflect.Method

// NOTE: This is a generic reflection helper used only by the plugin's unit tests.
/**
 * Invokes a method on the target instance.
 * @param methodName the name of the method
 * @param params the parameters to provide the method
 * @return the result from the invoked method
 */
@Suppress("SpreadOperator", "UNCHECKED_CAST", "TooGenericExceptionCaught", "UNUSED")
fun <T : Any> T.invokeMethod(
    methodName: String,
    vararg params: Any?
): Any? {
    val declarationParams = Array<Class<*>?>(params.size) {
        params[it]?.javaClass
    }

    val method = getDeclaredMethodRecursively(methodName, false, declarationParams)
    val wasAccessible = method.isAccessible

    val output: Any?
    method.isAccessible = true
    try {
        output = if (params.isEmpty()) {
            method.invoke(this)
        } else {
            method.invoke(this, *params)
        }
    } catch (e: InvocationTargetException) {
        throw e.cause ?: e
    } finally {
        method.isAccessible = wasAccessible
    }

    return output
}

@Suppress("TooGenericExceptionCaught", "SwallowedException", "SpreadOperator", "ComplexMethod")
private fun <T : Any> T.getDeclaredMethodRecursively(
    methodName: String,
    matchingParams: Boolean,
    declarationParams: Array<Class<*>?>
): Method {
    val classesToSearch = mutableListOf<Class<*>>(this.javaClass)
    val classesSearched = mutableListOf<Class<*>>()
    var method: Method?
    do {
        val lookingInClass = classesToSearch.removeAt(0)
        classesSearched.add(lookingInClass)
        method = try {
            if (matchingParams) {
                lookingInClass.getDeclaredMethod(methodName, *declarationParams)
            } else {
                lookingInClass.declaredMethods.firstOrNull {
                    it.name == methodName &&
                            it.parameterTypes.size == declarationParams.size
                }
            }
        } catch (e: Throwable) {
            null
        }

        val superclass = lookingInClass.superclass
        if (superclass != null &&
            !classesToSearch.contains(superclass) &&
            !classesSearched.contains(superclass)
        ) {
            classesToSearch.add(superclass)
        }
        lookingInClass.interfaces.forEach {
            if (!classesToSearch.contains(it) && !classesSearched.contains(it)) {
                classesToSearch.add(it)
            }
        }
    } while (method == null && classesToSearch.isNotEmpty())

    checkNotNull(method) {
        "Unable to access method $methodName on ${javaClass.canonicalName}"
    }

    return method
}

/**
 * Gets the field value from the target instance.
 * @param fieldName the name of the field
 */
inline fun <reified T, R : Any> R.getFieldValue(
    fieldName: String,
    enclosingClass: Class<R> = this.javaClass
): T {
    val field = enclosingClass.getDeclaredField(fieldName)
    field.isAccessible = true
    return field.get(this) as T
}