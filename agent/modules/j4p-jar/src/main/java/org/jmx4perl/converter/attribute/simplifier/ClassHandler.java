package org.jmx4perl.converter.attribute.simplifier;

import java.util.Map;

/*
 * jmx4perl - WAR Agent for exporting JMX via JSON
 *
 * Copyright (C) 2009 Roland Huß, roland@cpan.org
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License
 * as published by the Free Software Foundation; either version 2
 * of the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.
 *
 * A commercial license is available as well. Please contact roland@cpan.org for
 * further details.
 */

/**
 * @author roland
 * @since Jul 27, 2009
 */
public class ClassHandler extends SimplifierHandler<Class> {
    public ClassHandler() {
        super(Class.class);
    }

    void init(Map<String, Extractor<Class>> pStringExtractorMap) {
        pStringExtractorMap.put("name",new Extractor<Class>() {
            public Object extract(Class value) {
                return value.getName();
            }
        });
        pStringExtractorMap.put("interfaces",new Extractor<Class>() {
            public Object extract(Class value) throws SkipAttributeException {
                if (value.isInterface()) {
                    throw new SkipAttributeException();
                }
                return value.getInterfaces();
            }
        });
    }
}
